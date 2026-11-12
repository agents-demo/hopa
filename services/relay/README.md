# hopa-relay

The cloud half: phones talk to it, a linked PC dials out to it, and it forwards requests to the bridge on that PC. It never installs `hdc` code and never touches a device. The PC half (`cloud-link`, `hdc-tunnel`) stays in `services/bridge` (ADR-0009).

```
python -m hopa_relay relay --host 0.0.0.0 --port 8790
```
