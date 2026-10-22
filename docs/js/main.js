(function () {
  "use strict";

  var toggle = document.querySelector(".nav-toggle");
  var nav = document.querySelector(".nav");

  if (toggle && nav) {
    toggle.addEventListener("click", function () {
      var open = nav.classList.toggle("is-open");
      toggle.setAttribute("aria-expanded", open ? "true" : "false");
    });

    nav.querySelectorAll("a").forEach(function (link) {
      link.addEventListener("click", function () {
        nav.classList.remove("is-open");
        toggle.setAttribute("aria-expanded", "false");
      });
    });
  }

  var reduce =
    window.matchMedia &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  var nodes = Array.prototype.slice.call(document.querySelectorAll(".reveal"));

  function revealInView() {
    var height = window.innerHeight || document.documentElement.clientHeight;
    nodes.forEach(function (el) {
      if (el.classList.contains("is-visible")) return;
      var rect = el.getBoundingClientRect();
      if (rect.width === 0 && rect.height === 0) return;
      if (rect.top < height && rect.bottom > 0) {
        el.classList.add("is-visible");
      }
    });
  }

  if (!reduce) {
    nodes.forEach(function (el) {
      el.classList.add("is-pending");
    });

    if ("IntersectionObserver" in window) {
      var io = new IntersectionObserver(
        function (entries) {
          entries.forEach(function (entry) {
            if (entry.isIntersecting) {
              entry.target.classList.add("is-visible");
              io.unobserve(entry.target);
            }
          });
        },
        { rootMargin: "0px 0px -8% 0px", threshold: 0.12 }
      );
      nodes.forEach(function (el) {
        io.observe(el);
      });
    }

    revealInView();
    window.addEventListener("scroll", revealInView, { passive: true });
    window.addEventListener("resize", revealInView);
  } else {
    nodes.forEach(function (el) {
      el.classList.add("is-visible");
    });
  }
})();
