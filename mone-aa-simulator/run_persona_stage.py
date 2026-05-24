import json
from pathlib import Path

from mone_aa_sim.persona_agents import create_persona, critique_persona


OUT_DIR = Path("data/generated/personas")
OUT_DIR.mkdir(parents=True, exist_ok=True)


def run(persona_id: str, max_attempts: int = 5):
    for attempt in range(1, max_attempts + 1):
        print(f"\n=== Generating {persona_id} persona: attempt {attempt} ===")

        persona = create_persona(persona_id)
        critique = critique_persona(persona)

        print("\nCritic decision:", critique.decision)
        print("Blocking defects:", critique.blocking_defects)

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

        print("Rejected. Regenerating...")

    raise RuntimeError(f"Could not generate passing persona for {persona_id}")


if __name__ == "__main__":
    run("aarav")
    run("priya")