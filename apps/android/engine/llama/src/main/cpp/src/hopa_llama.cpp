#include <jni.h>

#include <atomic>
#include <string>
#include <vector>

#include "llama.h"

namespace {

struct Session {
    llama_model * model = nullptr;
    llama_context * context = nullptr;
    const llama_vocab * vocab = nullptr;
};

// One generation at a time: the engine runs on a single session, and the cancel
// flag is what the chat's stop button reaches.
std::atomic<bool> g_cancel{false};

std::string to_string(JNIEnv * env, jstring value) {
    if (value == nullptr) return {};
    const char * chars = env->GetStringUTFChars(value, nullptr);
    if (chars == nullptr) return {};
    std::string out(chars);
    env->ReleaseStringUTFChars(value, chars);
    return out;
}

}  // namespace

extern "C" {

JNIEXPORT jlong JNICALL
Java_com_hopa_localmodel_LlamaEngine_nativeLoad(
        JNIEnv * env,
        jobject /* thiz */,
        jstring path,
        jint contextTokens,
        jint threads) {
    const std::string modelPath = to_string(env, path);
    if (modelPath.empty()) return 0;

    llama_backend_init();

    llama_model_params modelParams = llama_model_default_params();
    modelParams.n_gpu_layers = 0;  // CPU only: the NPU is not wired up yet.
    llama_model * model = llama_model_load_from_file(modelPath.c_str(), modelParams);
    if (model == nullptr) return 0;

    llama_context_params contextParams = llama_context_default_params();
    contextParams.n_ctx = static_cast<uint32_t>(contextTokens);
    contextParams.n_batch = 512;
    contextParams.n_threads = threads;
    contextParams.n_threads_batch = threads;
    llama_context * context = llama_init_from_model(model, contextParams);
    if (context == nullptr) {
        llama_model_free(model);
        return 0;
    }

    auto * session = new Session{model, context, llama_model_get_vocab(model)};
    return reinterpret_cast<jlong>(session);
}

JNIEXPORT void JNICALL
Java_com_hopa_localmodel_LlamaEngine_nativeFree(JNIEnv * /* env */, jobject /* thiz */, jlong handle) {
    auto * session = reinterpret_cast<Session *>(handle);
    if (session == nullptr) return;
    llama_free(session->context);
    llama_model_free(session->model);
    delete session;
}

JNIEXPORT void JNICALL
Java_com_hopa_localmodel_LlamaEngine_nativeCancel(JNIEnv * /* env */, jobject /* thiz */) {
    g_cancel.store(true);
}

JNIEXPORT jstring JNICALL
Java_com_hopa_localmodel_LlamaEngine_nativeApplyTemplate(
        JNIEnv * env,
        jobject /* thiz */,
        jlong handle,
        jobjectArray roles,
        jobjectArray contents) {
    auto * session = reinterpret_cast<Session *>(handle);
    if (session == nullptr || roles == nullptr || contents == nullptr) {
        return env->NewStringUTF("");
    }
    const char * tmpl = llama_model_chat_template(session->model, nullptr);
    if (tmpl == nullptr) {
        return env->NewStringUTF("");
    }
    const jsize count = env->GetArrayLength(roles);
    if (count <= 0 || count != env->GetArrayLength(contents)) {
        return env->NewStringUTF("");
    }
    std::vector<std::string> roleText;
    std::vector<std::string> contentText;
    roleText.reserve(static_cast<size_t>(count));
    contentText.reserve(static_cast<size_t>(count));
    for (jsize index = 0; index < count; ++index) {
        auto role = static_cast<jstring>(env->GetObjectArrayElement(roles, index));
        auto content = static_cast<jstring>(env->GetObjectArrayElement(contents, index));
        roleText.push_back(to_string(env, role));
        contentText.push_back(to_string(env, content));
        env->DeleteLocalRef(role);
        env->DeleteLocalRef(content);
    }
    std::vector<llama_chat_message> messages;
    messages.reserve(static_cast<size_t>(count));
    for (jsize index = 0; index < count; ++index) {
        messages.push_back({roleText[static_cast<size_t>(index)].c_str(),
                            contentText[static_cast<size_t>(index)].c_str()});
    }
    const int32_t needed = llama_chat_apply_template(
            tmpl, messages.data(), messages.size(), true, nullptr, 0);
    if (needed <= 0) {
        return env->NewStringUTF("");
    }
    std::vector<char> buffer(static_cast<size_t>(needed) + 1);
    const int32_t written = llama_chat_apply_template(
            tmpl, messages.data(), messages.size(), true, buffer.data(),
            static_cast<int32_t>(buffer.size()));
    if (written <= 0) {
        return env->NewStringUTF("");
    }
    buffer[static_cast<size_t>(written)] = '\0';
    return env->NewStringUTF(buffer.data());
}

JNIEXPORT jstring JNICALL
Java_com_hopa_localmodel_LlamaEngine_nativeCompleteStream(
        JNIEnv * env,
        jobject /* thiz */,
        jlong handle,
        jstring prompt,
        jint maxTokens,
        jstring grammar,
        jfloat temperature,
        jfloat topP,
        jint topK,
        jfloat repeatPenalty,
        jobject sink) {
    auto * session = reinterpret_cast<Session *>(handle);
    if (session == nullptr) return env->NewStringUTF("");

    g_cancel.store(false);
    // A completion is stateless: the previous turn's tokens must not leak in.
    llama_memory_clear(llama_get_memory(session->context), true);

    jclass sinkClass = nullptr;
    jmethodID sinkMethod = nullptr;
    if (sink != nullptr) {
        sinkClass = env->GetObjectClass(sink);
        sinkMethod = env->GetMethodID(sinkClass, "onToken", "(Ljava/lang/String;)V");
    }

    const std::string text = to_string(env, prompt);
    if (text.empty()) return env->NewStringUTF("");

    // Tokenise. A negative result says how large the buffer must be.
    int32_t capacity = static_cast<int32_t>(text.size()) + 8;
    std::vector<llama_token> tokens(static_cast<size_t>(capacity));
    int32_t count = llama_tokenize(
            session->vocab, text.c_str(), static_cast<int32_t>(text.size()),
            tokens.data(), capacity, true, true);
    if (count < 0) {
        capacity = -count;
        tokens.resize(static_cast<size_t>(capacity));
        count = llama_tokenize(
                session->vocab, text.c_str(), static_cast<int32_t>(text.size()),
                tokens.data(), capacity, true, true);
    }
    if (count <= 0) return env->NewStringUTF("");
    tokens.resize(static_cast<size_t>(count));

    llama_sampler_chain_params samplerParams = llama_sampler_chain_default_params();
    llama_sampler * chain = llama_sampler_chain_init(samplerParams);
    if (repeatPenalty > 1.0f) {
        llama_sampler_chain_add(
                chain,
                llama_sampler_init_penalties(
                        llama_vocab_n_tokens(session->vocab), 64, repeatPenalty, 0.0f, 0.0f));
    }
    // The grammar masks logits before they are truncated, so a constrained
    // token can never be removed by top-k or top-p.
    const std::string grammarText = to_string(env, grammar);
    if (!grammarText.empty()) {
        llama_sampler * constrained =
                llama_sampler_init_grammar(session->vocab, grammarText.c_str(), "root");
        if (constrained != nullptr) llama_sampler_chain_add(chain, constrained);
    }
    if (topK > 0) {
        llama_sampler_chain_add(chain, llama_sampler_init_top_k(topK));
    }
    llama_sampler_chain_add(chain, llama_sampler_init_top_p(topP, 1));
    llama_sampler_chain_add(chain, llama_sampler_init_min_p(0.05f, 1));
    if (temperature > 0.0f) {
        llama_sampler_chain_add(chain, llama_sampler_init_temp(temperature));
        llama_sampler_chain_add(chain, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));
    } else {
        llama_sampler_chain_add(chain, llama_sampler_init_greedy());
    }

    // The prompt never fits one batch: a plan prompt is far longer than the
    // 512-token batch the context was created with, and llama_decode() aborts
    // the process when a batch is larger than n_batch. Decode it in chunks.
    const int32_t batchLimit = 512;
    const int32_t contextLimit = static_cast<int32_t>(llama_n_ctx(session->context));
    // Reserve the reply and the few tokens a chat template adds around it.
    if (count > contextLimit - maxTokens - 64) {
        // Keep the tail: instructions and the task live at the end of the prompt.
        const int32_t keep = contextLimit - maxTokens - 64;
        if (keep <= 0) {
            llama_sampler_free(chain);
            return env->NewStringUTF("");
        }
        tokens.erase(tokens.begin(), tokens.end() - keep);
        count = keep;
    }
    for (int32_t offset = 0; offset < count; offset += batchLimit) {
        const int32_t size = std::min(batchLimit, count - offset);
        llama_batch chunk = llama_batch_get_one(tokens.data() + offset, size);
        if (llama_decode(session->context, chunk) != 0) {
            llama_sampler_free(chain);
            return env->NewStringUTF("");
        }
    }

    std::string out;
    for (int32_t generated = 0; generated < maxTokens && !g_cancel.load(); ++generated) {
        llama_token token = llama_sampler_sample(chain, session->context, -1);
        if (llama_vocab_is_eog(session->vocab, token)) break;
        char piece[256];
        const int32_t length =
                llama_token_to_piece(session->vocab, token, piece, sizeof(piece), 0, true);
        if (length > 0) {
            out.append(piece, static_cast<size_t>(length));
            if (sink != nullptr && sinkMethod != nullptr) {
                jstring chunk = env->NewStringUTF(std::string(piece, static_cast<size_t>(length)).c_str());
                env->CallVoidMethod(sink, sinkMethod, chunk);
                env->DeleteLocalRef(chunk);
            }
        }
        llama_batch next = llama_batch_get_one(&token, 1);
        if (llama_decode(session->context, next) != 0) break;
    }

    llama_sampler_free(chain);
    if (sinkClass != nullptr) env->DeleteLocalRef(sinkClass);
    return env->NewStringUTF(out.c_str());
}

}  // extern "C"
