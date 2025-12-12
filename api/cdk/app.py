#!/usr/bin/env python3
"""CDK App entry point for CycleJournal API."""

import os

import aws_cdk as cdk

from stacks.api_stack import CycleJournalApiStack

app = cdk.App()

# 環境設定
env = cdk.Environment(
    account=os.environ.get("CDK_DEFAULT_ACCOUNT"),
    region=os.environ.get("CDK_DEFAULT_REGION", "ap-northeast-1"),
)

# コンテキストから環境名を取得（デフォルト: dev）
stage = app.node.try_get_context("stage") or "dev"

# APIスタック
CycleJournalApiStack(
    app,
    f"CycleJournal-{stage}",
    stage=stage,
    env=env,
)

app.synth()
