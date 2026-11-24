using System.Text.Json.Nodes;

// A minimal NDJSON host for the integration tests: one reply by id, then exit
// on shutdown. It is not the real sidecar; it only proves the wire.
var memory = new List<string>();
var skills = new List<(string Trigger, string Action)>();

string? line;
while ((line = Console.In.ReadLine()) != null)
{
    var message = JsonNode.Parse(line) as JsonObject;
    var type = message?["type"]?.GetValue<string>() ?? "";
    if (type == "shutdown")
    {
        break;
    }

    var id = message?["id"]?.GetValue<string>() ?? "";
    var reply = new JsonObject
    {
        ["type"] = type,
        ["id"] = id,
    };

    switch (type)
    {
        case "memory.list":
            reply["ok"] = true;
            reply["items"] = Strings(memory);
            break;
        case "memory.add":
            var fact = message?["text"]?.GetValue<string>() ?? "";
            if (fact.Length == 0)
            {
                Error(reply, "E_SCHEMA", "text is empty");
            }
            else
            {
                if (!memory.Contains(fact))
                {
                    memory.Add(fact);
                }

                reply["type"] = "memory.list";
                reply["ok"] = true;
                reply["items"] = Strings(memory);
            }

            break;
        case "memory.delete":
            memory.Remove(message?["text"]?.GetValue<string>() ?? "");
            reply["type"] = "memory.list";
            reply["ok"] = true;
            reply["items"] = Strings(memory);
            break;
        case "memory.clear":
            memory.Clear();
            reply["type"] = "memory.list";
            reply["ok"] = true;
            reply["items"] = Strings(memory);
            break;
        case "skills.list":
            reply["ok"] = true;
            reply["items"] = SkillItems(skills);
            break;
        case "skills.add":
            var trigger = message?["trigger"]?.GetValue<string>() ?? "";
            var action = message?["action"]?.GetValue<string>() ?? "";
            if (trigger.Length == 0 || action.Length == 0)
            {
                Error(reply, "E_SCHEMA", "trigger and action are required");
            }
            else
            {
                skills.RemoveAll(skill => skill.Trigger == trigger);
                skills.Add((trigger, action));
                reply["type"] = "skills.list";
                reply["ok"] = true;
                reply["items"] = SkillItems(skills);
            }

            break;
        case "skills.delete":
            skills.RemoveAll(skill => skill.Trigger == (message?["trigger"]?.GetValue<string>() ?? ""));
            reply["type"] = "skills.list";
            reply["ok"] = true;
            reply["items"] = SkillItems(skills);
            break;
        case "skills.clear":
            skills.Clear();
            reply["type"] = "skills.list";
            reply["ok"] = true;
            reply["items"] = SkillItems(skills);
            break;
        default:
            reply["answer"] = "hello";
            reply["conversationId"] = "c1";
            break;
    }

    Console.Out.WriteLine(reply.ToJsonString());
    Console.Out.Flush();
}

static JsonArray Strings(IEnumerable<string> values)
{
    var array = new JsonArray();
    foreach (var value in values)
    {
        array.Add(value);
    }

    return array;
}

static JsonArray SkillItems(IEnumerable<(string Trigger, string Action)> values)
{
    var array = new JsonArray();
    foreach (var (trigger, action) in values)
    {
        array.Add(new JsonObject { ["trigger"] = trigger, ["action"] = action });
    }

    return array;
}

static void Error(JsonObject reply, string code, string message)
{
    reply["ok"] = false;
    reply["code"] = code;
    reply["error"] = message;
}
