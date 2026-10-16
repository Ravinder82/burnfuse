// BurnFuse website — precise, patient motion.
(() => {
  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* ---------- sticky nav hairline on scroll ---------- */
  const nav = document.getElementById("nav");
  const onScroll = () => nav && nav.classList.toggle("scrolled", window.scrollY > 8);
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  /* ---------- scroll reveals + clip wipes ---------- */
  const io = new IntersectionObserver(
    (entries) => {
      for (const e of entries) {
        if (e.isIntersecting) {
          e.target.classList.add("in");
          io.unobserve(e.target);
        }
      }
    },
    { threshold: 0.12, rootMargin: "0px 0px -8% 0px" }
  );
  document.querySelectorAll("[data-reveal], [data-wipe], [data-film]").forEach((el) => io.observe(el));

  // Safety net: anything already in view reveals even if the observer is late.
  const revealInView = () => {
    document.querySelectorAll("[data-reveal]:not(.in), [data-wipe]:not(.in), [data-film]:not(.in)").forEach((el) => {
      const r = el.getBoundingClientRect();
      if (r.top < window.innerHeight && r.bottom > 0) el.classList.add("in");
    });
  };
  window.addEventListener("load", () => setTimeout(revealInView, 200));
  setTimeout(revealInView, 1000);

  /* ---------- pipeline: run the flow while visible ---------- */
  const pipeline = document.getElementById("pipeline");
  if (pipeline) {
    if (reduced) {
      pipeline.classList.add("live");
    } else {
      const pio = new IntersectionObserver(
        (entries) => {
          for (const e of entries) pipeline.classList.toggle("live", e.isIntersecting);
        },
        { threshold: 0.25 }
      );
      pio.observe(pipeline);
    }
  }

  /* ---------- the premiere: play on screen, with a pause control ---------- */
  const reel = document.querySelector("video.reel");
  const reelToggle = document.querySelector(".film-toggle");
  if (reel) {
    let userPaused = !!reduced;
    const setToggle = () => {
      if (!reelToggle) return;
      reelToggle.textContent = userPaused ? "Play" : "Pause";
      reelToggle.setAttribute("aria-pressed", String(userPaused));
    };
    if (reduced) {
      reel.removeAttribute("autoplay");
      reel.pause();
    }
    setToggle();
    if (reelToggle) {
      reelToggle.addEventListener("click", () => {
        userPaused = !userPaused;
        if (userPaused) reel.pause();
        else reel.play().catch(() => {});
        setToggle();
      });
    }
    const vio = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (userPaused) continue;
          if (e.isIntersecting) reel.play().catch(() => {});
          else reel.pause();
        }
      },
      { threshold: 0.25 }
    );
    vio.observe(reel);
  }

  /* ---------- the block demo: settled → climbing → tripped ---------- */
  const block = document.getElementById("block");
  const rate = document.getElementById("rate");
  const legends = [...document.querySelectorAll(".legend-item")];

  if (block && rate) {
    const states = [
      { key: "calm", value: 2.45 },
      { key: "warm", value: 9.8 },
      { key: "hot", value: 16.4 },
    ];
    let index = 0;
    let current = states[0].value;
    let raf = null;
    let ticker = null;

    const render = (v) => {
      rate.textContent = `$${v.toFixed(2)}/hr`;
    };

    const apply = (i) => {
      const s = states[i];
      block.dataset.state = s.key;
      legends.forEach((el, n) => el.classList.toggle("active", n === i));

      if (s.key === "hot" && !reduced) {
        block.classList.remove("trip");
        void block.offsetWidth; // restart the shake
        block.classList.add("trip");
      }

      if (reduced) {
        current = s.value;
        render(current);
        return;
      }

      const from = current;
      const to = s.value;
      let base = null;
      const dur = 900;
      cancelAnimationFrame(raf);
      const step = (t) => {
        if (base === null) base = t; // rAF's own clock — immune to clock drift
        const p = Math.max(0, Math.min(1, (t - base) / dur));
        const e = 1 - Math.pow(1 - p, 3); // easeOutCubic
        current = from + (to - from) * e;
        render(current);
        if (p < 1) raf = requestAnimationFrame(step);
      };
      raf = requestAnimationFrame(step);
    };

    const start = () => {
      if (ticker || reduced) return;
      ticker = setInterval(() => {
        index = (index + 1) % states.length;
        apply(index);
      }, 3200);
    };
    const stop = () => {
      if (ticker) clearInterval(ticker);
      ticker = null;
    };

    apply(0);

    const bio = new IntersectionObserver(
      (entries) => {
        for (const e of entries) (e.isIntersecting ? start : stop)();
      },
      { threshold: 0.35 }
    );
    bio.observe(block);
  }
})();
