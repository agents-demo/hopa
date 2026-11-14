"""HOPA reference agent for the PC-tethered evaluation rig."""

from __future__ import annotations

__version__ = "0.1.0"

from .actions import Action
from .errors import (
    ActionError,
    AgentError,
    CapabilityError,
    ModelError,
    PolicyError,
    SchemaError,
)
from .executor import DeviceExecutor, Outcome
from .loop import AgentLoop, RunResult
from .models import ModelDecision, OpenAIClient, StubModelClient
from .observation import Observation, observation_from_layout
from .policy import ApprovalPolicy, ApprovalRequest, Decision, RiskLevel
from .records import RunRecord, RunStore

__all__ = [
    "Action",
    "ActionError",
    "AgentError",
    "AgentLoop",
    "ApprovalPolicy",
    "ApprovalRequest",
    "CapabilityError",
    "Decision",
    "DeviceExecutor",
    "ModelDecision",
    "ModelError",
    "Observation",
    "OpenAIClient",
    "Outcome",
    "PolicyError",
    "RiskLevel",
    "RunRecord",
    "RunResult",
    "RunStore",
    "SchemaError",
    "StubModelClient",
    "observation_from_layout",
]
