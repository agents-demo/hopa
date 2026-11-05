"""Typed errors shared by the loop, the gate and the harness.

The codes are the contract in ``docs/contracts/errors.md``. Every error carries
a retryable flag and a user-facing message key so the UI never has to parse an
English string.
"""

from __future__ import annotations


class AgentError(RuntimeError):
    """Base class for every agent failure."""

    code = "E_AGENT"
    retryable = False
    message_key = "error.agent"

    def __init__(
        self,
        message: str,
        *,
        retryable: bool | None = None,
        message_key: str | None = None,
        trace_id: str | None = None,
    ) -> None:
        super().__init__(message)
        if retryable is not None:
            self.retryable = retryable
        if message_key is not None:
            self.message_key = message_key
        self.trace_id = trace_id

    def as_dict(self) -> dict:
        return {
            "code": self.code,
            "message": str(self),
            "retryable": self.retryable,
            "messageKey": self.message_key,
            "traceId": self.trace_id,
        }


class ModelError(AgentError):
    code = "E_MODEL"
    retryable = True
    message_key = "error.model"


class SchemaError(AgentError):
    code = "E_SCHEMA"
    message_key = "error.schema"


class ActionError(AgentError):
    code = "E_ACTION"
    message_key = "error.action"


class CapabilityError(AgentError):
    code = "E_CAPABILITY"
    message_key = "error.capability"


class PolicyError(AgentError):
    code = "E_POLICY"
    message_key = "error.policy"


class DeviceFailure(AgentError):
    code = "E_DEVICE"
    retryable = True
    message_key = "error.device"


class BudgetError(AgentError):
    code = "E_BUDGET"
    message_key = "error.budget"


class StagnationError(AgentError):
    code = "E_STAGNATION"
    message_key = "error.stagnation"


class TimeoutFailure(AgentError):
    code = "E_TIMEOUT"
    retryable = True
    message_key = "error.timeout"


class ScrollLimit(AgentError):
    code = "E_SCROLL"
    message_key = "error.scroll"


class HandoverRequired(AgentError):
    code = "E_HANDOVER"
    message_key = "error.handover"
