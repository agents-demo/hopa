# Appendix C â€” Contracts

### C.1 Observation

```json
{
  "id": "obs_01",
  "timestamp": 0,
  "displayId": 0,
  "windowId": "active",
  "rotation": 0,
  "density": 0,
  "screenSize": { "width": 0, "height": 0 },
  "focus": "e12",
  "text": "flattened visible text",
  "tree": { "ref": "e1", "type": "", "text": "", "bounds": [0, 0, 0, 0], "children": [] },
  "screenshotRef": "file://â€¦",
  "hash": "sha256:â€¦"
}
```

### C.2 Action

```json
{
  "kind": "ui.tap",
  "ref": "e12",
  "text": "",
  "x": 0, "y": 0,
  "app": "com.huawei.hmos.settings",
  "timeoutMs": 10000
}
```

### C.3 Decision

```json
{ "action": { }, "say": "one short sentence", "done": false, "needUser": false }
```

### C.4 Run record

```json
{
  "runId": "", "step": 0, "action": { }, "classification": "read|sensitive|payment",
  "approved": true, "observationHash": "", "verified": true, "error": null
}
```

---

