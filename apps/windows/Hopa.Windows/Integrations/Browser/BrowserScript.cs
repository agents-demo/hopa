using System;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.Json.Serialization;

namespace Hopa.Windows.Integrations.Browser;

/// <summary>
/// The URL rules for the engine's WebView2 surface. Only a web page is allowed:
/// a settings page or a local file belongs to the device adapter, not here.
/// </summary>
public static class BrowserPolicy
{
    /// <summary>Normalises an address and refuses anything that is not http/https.</summary>
    public static string Normalise(string text)
    {
        var value = (text ?? "").Trim();
        if (value.Length == 0)
        {
            throw new InvalidOperationException("the address is empty");
        }

        if (!value.Contains("://", StringComparison.Ordinal))
        {
            value = "https://" + value;
        }

        if (!Uri.TryCreate(value, UriKind.Absolute, out var uri))
        {
            throw new InvalidOperationException($"'{text}' is not a web address");
        }

        if (uri.Scheme is not ("http" or "https"))
        {
            throw new InvalidOperationException(
                $"the '{uri.Scheme}' scheme is not allowed; only http and https");
        }

        return uri.ToString();
    }

    /// <summary>Navigation may pass through about:blank while WebView2 starts.</summary>
    public static bool MayNavigate(string url) =>
        url.Equals("about:blank", StringComparison.OrdinalIgnoreCase) ||
        (Uri.TryCreate(url, UriKind.Absolute, out var uri) && uri.Scheme is "http" or "https");
}

/// <summary>One readable element on the page, with the ref click/type use.</summary>
public sealed record BrowserElement(
    [property: JsonPropertyName("ref")] string Ref,
    [property: JsonPropertyName("role")] string Role,
    [property: JsonPropertyName("name")] string Name);

/// <summary>The page as the model sees it: address, title, text and controls.</summary>
public sealed record BrowserPage(
    [property: JsonPropertyName("url")] string Url,
    [property: JsonPropertyName("title")] string Title,
    [property: JsonPropertyName("text")] string Text,
    [property: JsonPropertyName("elements")] IReadOnlyList<BrowserElement> Elements);

/// <summary>The answer to a click or a type.</summary>
public sealed record BrowserAction(
    [property: JsonPropertyName("ok")] bool Ok,
    [property: JsonPropertyName("error")] string? Error,
    [property: JsonPropertyName("text")] string? Text);

/// <summary>
/// The JavaScript that reads and drives a page, and the formatters around it.
/// Kept separate from WebView2 so the ref rules and the text format are tested
/// without a browser.
/// </summary>
public static class BrowserScript
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
    };

    /// <summary>Tags up to 120 controls and returns the page as a JSON string.</summary>
    public const string Read = """
        (function () {
          var selector = 'a,button,input,textarea,select,[role="button"],[role="link"],[role="textbox"],[role="checkbox"],[role="radio"],[role="combobox"],[contenteditable="true"]';
          var nodes = Array.prototype.slice.call(document.querySelectorAll(selector)).slice(0, 120);
          var elements = [];
          for (var i = 0; i < nodes.length; i += 1) {
            var el = nodes[i];
            var ref = 'w' + (i + 1);
            el.setAttribute('data-hopa-ref', ref);
            var role = el.getAttribute('role') || el.tagName.toLowerCase();
            var name = el.getAttribute('aria-label') || el.getAttribute('placeholder') || el.getAttribute('name') || '';
            if (!name && el.tagName !== 'INPUT' && el.tagName !== 'TEXTAREA') {
              name = (el.innerText || '').trim();
            }
            name = name.replace(/\s+/g, ' ').slice(0, 120);
            if (el.tagName === 'INPUT' && el.type === 'password') {
              name = '(password field)';
            }
            elements.push({ ref: ref, role: role, name: name });
          }
          var body = document.body ? document.body.innerText : '';
          body = body.replace(/\s+/g, ' ').trim().slice(0, 4000);
          return JSON.stringify({ url: location.href, title: document.title, text: body, elements: elements });
        })()
        """;

    /// <summary>Clicks the element tagged by the last read.</summary>
    public static string Click(string reference)
    {
        var refLiteral = JsonSerializer.Serialize(reference);
        return $$"""
            (function () {
              var ref = {{refLiteral}};
              var el = document.querySelector('[data-hopa-ref="' + ref + '"]');
              if (!el) { return JSON.stringify({ ok: false, error: 'stale ref; read the page again' }); }
              el.scrollIntoView({ block: 'center' });
              el.focus();
              el.click();
              return JSON.stringify({ ok: true, text: 'clicked ' + ref });
            })()
            """;
    }

    /// <summary>Types into a tagged field, or into whatever has focus.</summary>
    public static string Type(string text, string? reference)
    {
        var textLiteral = JsonSerializer.Serialize(text);
        var refLiteral = reference == null ? "null" : JsonSerializer.Serialize(reference);
        return $$"""
            (function () {
              var ref = {{refLiteral}};
              var text = {{textLiteral}};
              var el = ref ? document.querySelector('[data-hopa-ref="' + ref + '"]') : document.activeElement;
              if (!el || el === document.body) { return JSON.stringify({ ok: false, error: 'stale ref; read the page again' }); }
              el.scrollIntoView({ block: 'center' });
              el.focus();
              if (el.isContentEditable) {
                el.textContent = text;
              } else {
                var proto = el.tagName === 'TEXTAREA' ? window.HTMLTextAreaElement.prototype : window.HTMLInputElement.prototype;
                var setter = Object.getOwnPropertyDescriptor(proto, 'value');
                if (setter && setter.set) { setter.set.call(el, text); } else { el.value = text; }
              }
              el.dispatchEvent(new Event('input', { bubbles: true }));
              el.dispatchEvent(new Event('change', { bubbles: true }));
              return JSON.stringify({ ok: true, text: 'typed ' + text.length + ' chars' });
            })()
            """;
    }

    public static BrowserPage ParsePage(string json) =>
        JsonSerializer.Deserialize<BrowserPage>(json, JsonOptions)
        ?? throw new InvalidOperationException("the page returned no readable content");

    public static BrowserAction ParseAction(string json) =>
        JsonSerializer.Deserialize<BrowserAction>(json, JsonOptions)
        ?? throw new InvalidOperationException("the browser returned no answer");

    /// <summary>The text the model reads: page text, then controls with refs.</summary>
    public static string Format(BrowserPage page)
    {
        var lines = new List<string>
        {
            $"URL: {page.Url}",
            $"TITLE: {page.Title}",
        };
        foreach (var element in page.Elements)
        {
            var name = element.Name.Length == 0 ? "(no label)" : element.Name;
            lines.Add($"[{element.Ref}] {element.Role} \"{name}\"");
        }

        if (page.Text.Length > 0)
        {
            lines.Add("TEXT:");
            lines.Add(page.Text);
        }

        return string.Join('\n', lines);
    }

    /// <summary>Runs a script and unwraps the JSON string WebView2 returns.</summary>
    public static string Unwrap(string raw)
    {
        if (string.IsNullOrWhiteSpace(raw) || raw == "null")
        {
            return "";
        }

        return JsonNode.Parse(raw)?.GetValue<string>() ?? "";
    }
}
