import { GlassCard } from "./GlassCard";

const requirements = [
  { icon: "💻", label: "macOS 26 (Tahoe) or iOS 26" },
  { icon: "🧠", label: "Apple Silicon (M1 or later)" },
  { icon: "✨", label: "Apple Intelligence enabled" },
];

export function Requirements() {
  return (
    <section id="requirements" className="relative py-20 sm:py-28">
      <div className="mx-auto max-w-2xl px-4 sm:px-6 lg:px-8">
        <div className="mb-12 text-center">
          <h2 className="section-title mb-4 font-serif font-bold text-sj-text">
            System Requirements
          </h2>
        </div>

        <GlassCard className="p-8">
          <div className="flex flex-col items-center gap-4">
            {requirements.map((req) => (
              <div
                key={req.label}
                className="flex items-center gap-3 rounded-full border border-sj-border/40 bg-[var(--sj-card)]/60 px-5 py-2.5"
              >
                <span className="text-xl">{req.icon}</span>
                <span className="font-sans text-sm font-medium text-sj-text">
                  {req.label}
                </span>
              </div>
            ))}

            <div className="mt-4 h-px w-32 bg-gradient-to-r from-transparent via-sj-border to-transparent" />

            <p className="text-center font-sans text-sm text-sj-muted">
              Cloud features are optional. Use Hugging Face for access to larger
              models.
            </p>
          </div>
        </GlassCard>
      </div>
    </section>
  );
}
