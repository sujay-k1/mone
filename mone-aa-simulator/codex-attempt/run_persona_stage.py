import json
from pathlib import Path

from mone_aa_sim.persona_agents import create_persona, critique_persona


OUT_DIR = Path("data/generated/personas")
OUT_DIR.mkdir(parents=True, exist_ok=True)


def run(persona_id: str, max_attempts: int = 5):
    regeneration_feedback = None
    for attempt in range(1, max_attempts + 1):
        print(f"\n=== Generating {persona_id} persona: attempt {attempt} ===")

        persona = create_persona(persona_id, regeneration_feedback=regeneration_feedback)
        critique = critique_persona(persona)

        print("\nCritic decision:", critique.decision)
        if critique.blocking_defects:
            print("Blocking defects:")
            for defect in critique.blocking_defects:
                print(
                    f"- {defect.code}: {defect.why_blocking} | evidence: {defect.evidence}"
                )
        else:
            print("Blocking defects: []")

        attempt_path = OUT_DIR / f"{persona_id}_attempt_{attempt}.json"
        attempt_path.write_text(
            json.dumps(
                {
                    "persona": persona.model_dump(),
                    "critique": critique.model_dump(),
                },
                indent=2,
                ensure_ascii=False,
            )
        )

        if critique.decision == "PASS":
            final_path = OUT_DIR / f"{persona_id}.json"
            final_path.write_text(
                json.dumps(persona.model_dump(), indent=2, ensure_ascii=False)
            )
            print(f"\nPASS. Saved final persona to {final_path}")
            return persona

        if critique.decision == "REGENERATE_THIS_STAGE":
            feedback_lines = [critique.required_regeneration_scope]
            feedback_lines.extend(
                f"{defect.code}: {defect.evidence} | {defect.why_blocking}"
                for defect in critique.blocking_defects
            )
            regeneration_feedback = "\n".join(feedback_lines)
            print("Rejected at this stage. Regenerating persona...")
            continue

        if critique.decision == "SEND_BACK_TO_PREVIOUS_STAGE":
            raise RuntimeError(
                f"Critic requested SEND_BACK_TO_PREVIOUS_STAGE for {persona_id}: "
                f"{critique.required_regeneration_scope}"
            )

        if critique.decision == "REJECT_ASSUMPTION":
            raise RuntimeError(
                f"Critic requested REJECT_ASSUMPTION for {persona_id}: "
                f"{critique.required_regeneration_scope}"
            )

        raise RuntimeError(f"Unexpected critic decision: {critique.decision}")

    raise RuntimeError(f"Could not generate passing persona for {persona_id}")


if __name__ == "__main__":
    run("aarav")
    run("priya")
