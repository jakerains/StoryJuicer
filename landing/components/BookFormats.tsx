"use client";

import { motion } from "framer-motion";
import { fadeUpVariants, staggerContainer } from "@/lib/motion";
import { GlassCard } from "./GlassCard";

const formats = [
  {
    name: "Standard Square",
    dimensions: '8.5" × 8.5"',
    aspect: "aspect-square",
    width: "w-28",
  },
  {
    name: "Landscape",
    dimensions: '11" × 8.5"',
    aspect: "aspect-[11/8.5]",
    width: "w-36",
  },
  {
    name: "Portrait",
    dimensions: '8.5" × 11"',
    aspect: "aspect-[8.5/11]",
    width: "w-24",
  },
  {
    name: "Small Square",
    dimensions: '6" × 6"',
    aspect: "aspect-square",
    width: "w-20",
  },
];

export function BookFormats() {
  return (
    <section id="formats" className="relative py-20 sm:py-28">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <motion.div
          className="mb-16 text-center"
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, amount: 0.3 }}
          variants={fadeUpVariants}
        >
          <h2 className="section-title mb-4 font-serif font-bold text-sj-text">
            Four Book Formats
          </h2>
          <p className="mx-auto max-w-xl text-lg text-sj-secondary">
            Professional print dimensions for every type of story.
          </p>
        </motion.div>

        <motion.div
          className="grid grid-cols-2 gap-6 md:grid-cols-4"
          variants={staggerContainer}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, amount: 0.15 }}
        >
          {formats.map((format) => (
            <motion.div key={format.name} variants={fadeUpVariants}>
              <GlassCard className="flex flex-col items-center p-6" hover>
                {/* Format preview rectangle */}
                <div className="mb-5 flex items-center justify-center" style={{ minHeight: 120 }}>
                  <div
                    className={`${format.aspect} ${format.width} rounded-lg bg-gradient-to-br from-sj-coral/20 to-sj-highlight/20 ring-1 ring-sj-border/40`}
                  />
                </div>

                <h3 className="mb-1 text-center font-serif text-base font-semibold text-sj-text">
                  {format.name}
                </h3>
                <p className="text-center font-sans text-sm text-sj-muted">
                  {format.dimensions}
                </p>
              </GlassCard>
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  );
}
