"""Copy a saved prompt version to prod DB and mark it as current.

This is intended for CI/CD. It reads a version from the dev Firestore database,
writes the same immutable version document into the target database, and updates
prompt_deployments/current in the target database.
"""

from __future__ import annotations

import argparse
import asyncio
from datetime import UTC, datetime

from google.cloud.firestore import AsyncClient


async def _run(args: argparse.Namespace) -> None:
    source_db = AsyncClient(project=args.project_id, database=args.source_database)
    target_db = AsyncClient(project=args.project_id, database=args.target_database)

    source_ref = source_db.collection("prompt_versions").document(args.version_id)
    source_snap = await source_ref.get()
    if not source_snap.exists:
        raise SystemExit(
            f"prompt version {args.version_id} not found in {args.source_database}"
        )

    version_data = source_snap.to_dict() or {}
    now = datetime.now(UTC)
    version_data["status"] = "production"
    version_data["promoted_at"] = now
    version_data["promoted_by"] = args.deployed_by
    version_data["source_database"] = args.source_database

    target_ref = target_db.collection("prompt_versions").document(args.version_id)
    await target_ref.set(version_data)
    await target_db.collection("prompt_deployments").document("current").set(
        {
            "environment": args.environment,
            "version_id": args.version_id,
            "deployed_by": args.deployed_by,
            "deployed_at": now,
        }
    )

    await source_db.close()
    await target_db.close()
    print(
        "deployed prompt version "
        f"{args.version_id} from {args.source_database} to {args.target_database}"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version-id", required=True)
    parser.add_argument("--project-id", default="cycle-journal")
    parser.add_argument("--source-database", default="dev-db")
    parser.add_argument("--target-database", default="(default)")
    parser.add_argument("--environment", default="prod")
    parser.add_argument("--deployed-by", default="github-actions")
    args = parser.parse_args()
    asyncio.run(_run(args))


if __name__ == "__main__":
    main()
