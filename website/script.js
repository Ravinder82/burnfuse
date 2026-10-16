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

  /* ---------- the premiere: a real player for the launch reel ---------- */
  const filmEl = document.getElementById("film");
  const pbtn = document.getElementById("pbtn");
  const scrub = document.getElementById("scrub");
  const ptime = document.getElementById("ptime");
  const snd = document.getElementById("snd");
  const player = document.getElementById("player");

  if (filmEl) {
    let userPaused = !!reduced;

    const fmt = (s) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, "0")}`;

    const paint = () => {
      const d = filmEl.duration || 0;
      const pct = d ? (filmEl.currentTime / d) * 100 : 0;
      if (scrub && document.activeElement !== scrub) scrub.value = String(Math.round(pct * 10));
      if (ptime) ptime.textContent = `${fmt(filmEl.currentTime)} / ${fmt(d)}`;
      if (player) player.style.setProperty("--p", `${pct}%`);
      if (pbtn) {
        pbtn.classList.toggle("is-paused", filmEl.paused);
        pbtn.setAttribute("aria-label", filmEl.paused ? "Play the launch reel" : "Pause the launch reel");
      }
    };

    const play = () => filmEl.play().catch(() => {});
    const pause = () => filmEl.pause();
    const toggle = () => {
      if (filmEl.paused) { userPaused = false; play(); }
      else { userPaused = true; pause(); }
    };

    if (reduced) {
      filmEl.removeAttribute("autoplay");
      pause();
      // sit on the trip frame rather than the empty opening frame
      filmEl.addEventListener("loadedmetadata", () => {
        filmEl.currentTime = Math.min(5.6, (filmEl.duration || 6) - 0.2);
      });
    }
    ["timeupdate", "play", "pause", "loadedmetadata", "durationchange"].forEach((ev) =>
      filmEl.addEventListener(ev, paint)
    );
    if (pbtn) pbtn.addEventListener("click", toggle);
    filmEl.addEventListener("click", (e) => { if (e.target === filmEl) toggle(); });
    if (scrub) {
      scrub.addEventListener("input", () => {
        if (filmEl.duration) filmEl.currentTime = (Number(scrub.value) / 1000) * filmEl.duration;
      });
    }
    if (snd) {
      snd.addEventListener("click", () => {
        filmEl.muted = !filmEl.muted;
        snd.classList.toggle("is-on", !filmEl.muted);
        snd.setAttribute("aria-pressed", String(!filmEl.muted));
        snd.setAttribute("aria-label", filmEl.muted ? "Turn the sound on" : "Turn the sound off");
      });
    }

    const vio = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (userPaused) continue;
          if (e.isIntersecting) play();
          else pause();
        }
      },
      { threshold: 0.25 }
    );
    vio.observe(filmEl);
    paint();
  }

  /* ---------- the block demo: settled → climbing → tripped ---------- */
  const block = document.getElementById("block");
  const rate = document.getElementById("rate");
  const legends = [...document.querySelectorAll(".legend-item")];
  const rdno = document.getElementById("rdno");
  const rdstate = document.getElementById("rdstate");
  const rdrate = document.getElementById("rdrate");
  const rdpct = document.getElementById("rdpct");
  const fill = document.getElementById("rdfill");
  const meter = document.querySelector(".meter");
  const clock = document.getElementById("mbclock");

  if (block && rate) {
    const CAP = 5;
    const states = [
      { key: "calm", word: "settled", value: 2.45 },
      { key: "warm", word: "climbing", value: 9.8 },
      { key: "hot", word: "tripped", value: 16.4 },
    ];
    let index = 0;
    let current = states[0].value;
    let reading = 1;
    let clockT = 23 * 60 + 47; // 11:47 PM, one minute per reading
    let raf = null;
    let ticker = null;

    const render = (v) => {
      const pct = Math.round((v / CAP) * 100);
      rate.textContent = `$${v.toFixed(2)}/hr`;
      if (rdrate) rdrate.textContent = `$${v.toFixed(2)}/hr`;
      if (rdpct) rdpct.textContent = `${pct}%`;
      if (fill) fill.style.width = `${Math.min(pct, 100)}%`;
    };

    const tickClock = () => {
      if (!clock) return;
      clockT = (clockT + 1) % (24 * 60);
      const h24 = Math.floor(clockT / 60);
      const h = h24 % 12 === 0 ? 12 : h24 % 12;
      const mm = String(clockT % 60).padStart(2, "0");
      const ap = h24 < 12 ? "AM" : "PM";
      clock.innerHTML = `Fri&nbsp;${h}:${mm}&nbsp;${ap}`;
    };

    const show = (i) => {
      const s = states[i];
      block.dataset.state = s.key;
      legends.forEach((el, n) => el.classList.toggle("active", n === i));
      if (rdstate) { rdstate.textContent = s.word; rdstate.dataset.state = s.key; }
      if (meter) meter.dataset.state = s.key;
      if (s.key === "hot" && !reduced) {
        block.classList.remove("trip");
        void block.offsetWidth; // restart the shake
        block.classList.add("trip");
      }
    };

    // one new reading lands: the number moves, the minute ticks over
    const advance = (i) => {
      const s = states[i];
      show(i);
      reading += 1;
      if (rdno) rdno.textContent = String(reading).padStart(2, "0");
      tickClock();

      if (reduced) {
        current = s.value;
        render(current);
        return;
      }

      const from = current;
      const to = s.value;
      let base = null;
      const dur = 600;
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

    show(0);
    render(current);

    const start = () => {
      if (ticker || reduced) return;
      ticker = setInterval(() => {
        index = (index + 1) % states.length;
        advance(index);
      }, 2000);
    };
    const stop = () => {
      if (ticker) clearInterval(ticker);
      ticker = null;
    };

    const bio = new IntersectionObserver(
      (entries) => {
        for (const e of entries) (e.isIntersecting ? start : stop)();
      },
      { threshold: 0.35 }
    );
    bio.observe(block);
  }
})();
