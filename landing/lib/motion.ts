import type { Variants, Transition } from "framer-motion";

export const motionFast: Transition = { duration: 0.18, ease: "easeInOut" };
export const motionStandard: Transition = { duration: 0.24, ease: "easeInOut" };
export const motionEmphasis: Transition = { duration: 0.33, ease: "easeInOut" };

export const fadeUpVariants: Variants = {
  hidden: { opacity: 0, y: 24 },
  visible: { opacity: 1, y: 0, transition: motionEmphasis },
};

export const fadeInVariants: Variants = {
  hidden: { opacity: 0 },
  visible: { opacity: 1, transition: motionEmphasis },
};

export const scaleInVariants: Variants = {
  hidden: { opacity: 0, scale: 0.94 },
  visible: { opacity: 1, scale: 1, transition: motionStandard },
};

export const staggerContainer: Variants = {
  hidden: {},
  visible: {
    transition: { staggerChildren: 0.10, delayChildren: 0.08 },
  },
};

export const staggerFast: Variants = {
  hidden: {},
  visible: {
    transition: { staggerChildren: 0.06, delayChildren: 0.04 },
  },
};
