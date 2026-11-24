using System.Text.Json.Nodes;

// A minimal NDJSON host for the integration tests: one reply by id, then exit
// on shutdown. It is not the real sidecar; it only proves the wire.
string? line;
while ((line = Console.In.ReadLine()) != null)
{
    var message = JsonNode.Parse(line) as JsonObject;
    var type = message?["type"]?.GetValue<string>() ?? "";
    if (type == "shutdown")
    {
        break;
    }

    var reply = new JsonObject
    {
        ["type"] = type,
        ["id"] = message?["id"]?.GetValue<string>() ?? "",
        ["answer"] = "hello",
        ["conversationId"] = "c1",
    };
    Console.Out.WriteLine(reply.ToJsonString());
    Console.Out.Flush();
}
