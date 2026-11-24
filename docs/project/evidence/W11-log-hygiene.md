# W11 log hygiene

Status: **pass for the diagnostic surfaces; one explicit product exception.**

## What counts as a log

- `MainWindow.Log` and the `--out` transcript;
- sidecar stderr (`io.log`);
- desktop-check transcripts;
- the release package has no crash-dump uploader.

The chat answer itself is product output. `MainWindow.Log("HOPA: ...")` is the
user-visible conversation, not a diagnostic dump; it is called out here so the
exception is deliberate.

## Findings and fixes

| Surface | Before | After / reason |
|---|---|---|
| Approval log | `approval: allow ... {title}` | title removed. The title can quote a merchant or screen text; the log now records only the decision and source. Regression: `TheApprovalTitleNeverEntersTheLog`. |
| Open-link log | `device: {opened}` | `opened` can repeat a URL with a token. The log now says only `device: opened a link`; the URL still goes to the engine as the action result. Regression: `TheOpenLinkLogDoesNotRepeatTheUrl`. |
| Sidecar turn log | `turn <id> in <conversation>` | no goal, no screen tree, no typed text. The goal is persisted in the chat store, never logged. |
| Device observation log | app name + node count | no tree text or node labels. |
| Browser log | `browser: <op> ok` / error text | no page text; a provider error may still quote a URL, which is treated as action context, not screen content. |
| Screenshots | explicit paths only | filenames contain the surface, not screen text. |
| Crash dumps | no product uploader | Windows Error Reporting may create a local dump if the OS is configured to; HOPA does not collect or upload one. |

## Regression tests

```text
dotnet test apps/windows/Hopa.Windows.Tests -c Debug
```

- `ApprovalRouterTests.TheApprovalTitleNeverEntersTheLog`
- `DeviceRequestRouterTests.TheOpenLinkLogDoesNotRepeatTheUrl`
- existing `ObservationRulesTests.PasswordFieldsNeverEnterTheText`

## Remaining caveat

The user-facing chat transcript still contains the model's answer, which may
quote the screen. That is the product surface, not a diagnostic log; hiding it
would break the turn evidence. If the release policy later requires a redacted
transcript, that is a new product decision, not a log fix.
