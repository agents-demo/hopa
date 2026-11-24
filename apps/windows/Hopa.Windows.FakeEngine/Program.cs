using System.Text.Json.Nodes;

// A minimal NDJSON host for the integration tests: one reply by id, then exit
// on shutdown. It is not the real sidecar; it only proves the wire.
var memory = new List<string>();
var skills = new List<(string Trigger, string Action)>();
var recipes = new List<(string Goal, string App)> { ("open mail", "mail") };

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
        case "history.list":
            reply["ok"] = true;
            reply["items"] = new JsonArray
            {
                new JsonObject
                {
                    ["conversationId"] = "c1",
                    ["title"] = "Say hello",
                    ["runId"] = "run-1",
                    ["createdAt"] = 123,
                    ["steps"] = 2,
                    ["executed"] = 1,
                    ["failed"] = 1,
                },
            };
            break;
        case "usage.summary":
            reply["ok"] = true;
            reply["total"] = 2;
            reply["executed"] = 1;
            reply["failed"] = 1;
            reply["payments"] = 0;
            reply["lastSevenDays"] = 2;
            reply["topActions"] = new JsonArray
            {
                new JsonObject { ["kind"] = "ui.tap", ["count"] = 1 },
                new JsonObject { ["kind"] = "ui.type", ["count"] = 1 },
            };
            break;
        case "recipes.list":
            reply["ok"] = true;
            reply["items"] = RecipeItems(recipes);
            break;
        case "recipes.delete":
            recipes.RemoveAll(recipe => recipe.Goal == (message?["goal"]?.GetValue<string>() ?? ""));
            reply["type"] = "recipes.list";
            reply["ok"] = true;
            reply["items"] = RecipeItems(recipes);
            break;
        case "recipes.clear":
            recipes.Clear();
            reply["type"] = "recipes.list";
            reply["ok"] = true;
            reply["items"] = RecipeItems(recipes);
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

static JsonArray RecipeItems(IEnumerable<(string Goal, string App)> values)
{
    var array = new JsonArray();
    foreach (var (goal, app) in values)
    {
        array.Add(new JsonObject
        {
            ["goal"] = goal,
            ["app"] = app,
            ["steps"] = 2,
            ["at"] = 123,
            ["replayable"] = true,
            ["screenHash"] = "sha256:before",
            ["endHash"] = "sha256:after",
        });
    }

    return array;
}

static void Error(JsonObject reply, string code, string message)
{
    reply["ok"] = false;
    reply["code"] = code;
    reply["error"] = message;
}
