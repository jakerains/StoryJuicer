"use client";

import { motion } from "framer-motion";
import { changelog, type ChangelogChange } from "@/lib/changelog";
import { fadeUpVariants, staggerContainer } from "@/lib/motion";
import { GlassCard } from "./GlassCard";

const changeTypeConfig: Record<
  ChangelogChange["type"],
  { label: string; bg: string; text: string }
> = {
  added: {
    label: "Added",
    bg: "bg-emerald-500/10 dark:bg-emerald-400/10",
    text: "text-emerald-700 dark:text-emerald-400",
  },
  fixed: {
    label: "Fixed",
    bg: "bg-sj-coral/10",
    text: "text-sj-coral",
  },
  changed: {
    label: "Changed",
    bg: "bg-sj-gold/10",
    text: "text-sj-gold",
  },
  removed: {
    label: "Removed",
    bg: "bg-purple-500/10 dark:bg-purple-400/10",
    text: "text-purple-700 dark:text-purple-400",
  },
};

function ChangeBadge({ type }: { type: ChangelogChange["type"] }) {
  const config = changeTypeConfig[type];
  return (
    <span
      className={`inline-block rounded-full px-2 py-0.5 text-xs font-semibold ${config.bg} ${config.text}`}
    >
      {config.label}
    </span>
  );
}

export function ChangelogTimeline() {
  return (
    <motion.div
      className="mt-12 space-y-8"
      variants={staggerContainer}
      initial="hidden"
      animate="visible"
    >
      {changelog.map((entry) => (
        <motion.div key={entry.version} variants={fadeUpVariants}>
          <GlassCard className="p-6 sm:p-8">
            <div className="flex flex-wrap items-center gap-3">
              <span className="rounded-full bg-sj-gold/10 px-3 py-1 text-sm font-bold text-sj-gold">
                v{entry.version}
              </span>
              <time
                dateTime={entry.date}
                className="text-sm text-sj-muted"
              >
                {formatDate(entry.date)}
              </time>
            </div>

            <h2 className="mt-3 font-serif text-xl font-bold text-sj-text sm:text-2xl">
              {entry.title}
            </h2>

            <ul className="mt-5 space-y-3">
              {entry.changes.map((change, i) => (
                <li key={i} className="flex items-start gap-3">
                  <div className="mt-0.5 shrink-0">
                    <ChangeBadge type={change.type} />
                  </div>
                  <span className="text-sm leading-relaxed text-sj-secondary sm:text-base">
                    {change.description}
                  </span>
                </li>
              ))}
            </ul>
          </GlassCard>
        </motion.div>
      ))}
    </motion.div>
  );
}

function formatDate(dateString: string): string {
  const date = new Date(dateString + "T00:00:00");
  return date.toLocaleDateString("en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });
}
