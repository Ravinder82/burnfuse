// BurnFuse website — precise, patient reveals. Apple-ad timing.
(() => {
  const prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("visible");
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.12, rootMargin: "0px 0% -10% 0%" }
  );

  document.querySelectorAll("[data-scroll], .reveal").forEach((el) => {
    if (!prefersReduced) el.classList.add("reveal");
    el.classList.add("visible"); // reduced-motion: show immediately
    observer.observe(el);
  });

  // Kicker + lede type-in feel on load (subtle, not glitchy)
  const kicker = document.getElementById("kicker");
  const lede = document.getElementById("lede");
  if (kicker && !prefersReduced) {
    kicker.style.opacity = "0";
    kicker.style.transform = "translateY(14px)";
    kicker.style.transition = "opacity 0.7s ease, transform 0.7s ease";
    requestAnimationFrame(() => {
      kicker.style.opacity = "1";
      kicker.style.transform = "translateY(0)";
    });
  }
  if (lede && !prefersReduced) {
    lede.style.opacity = "0";
    lede.style.transform = "translateY(14px)";
    lede.style.transition = "opacity 0.9s ease, transform 0.9s ease";
    requestAnimationFrame(() => {
      lede.style.opacity = "1";
      lede.style.transform = "translateY(0)";
    });
  }
})();
