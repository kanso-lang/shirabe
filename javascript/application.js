// shirabe's JavaScript. senro's page script loads this once and morphs each
// later page into the live one, so it listens on the document rather than
// on elements that a page change replaces.

// An album's tracks are put in order by dragging them by their handles,
// with a mouse or a finger. Where one is dropped is sent as its new place,
// numbered from 1, and the server moves the others to make room.
let drag = null;

document.addEventListener("pointerdown", (e) => {
  const handle = e.target.closest("[data-reorder] .handle");
  if (!handle) return;
  e.preventDefault();
  const item = handle.closest("li");
  const list = item.parentElement;
  handle.setPointerCapture(e.pointerId);
  drag = { item, list, from: [...list.children].indexOf(item) };
  item.classList.add("dragging");
});

document.addEventListener("pointermove", (e) => {
  if (!drag) return;
  const { item, list } = drag;
  const below = [...list.children].find((li) => {
    if (li === item) return false;
    const box = li.getBoundingClientRect();
    return e.clientY < box.top + box.height / 2;
  });
  if (below && below !== item.nextElementSibling) list.insertBefore(item, below);
  if (!below && list.lastElementChild !== item) list.append(item);
});

const dropped = async () => {
  if (!drag) return;
  const { item, list, from } = drag;
  drag = null;
  item.classList.remove("dragging");
  const to = [...list.children].indexOf(item);
  if (to === from) return;
  const body = new URLSearchParams({ _method: "PATCH", position: String(to + 1) });
  const answer = await fetch(item.dataset.path, { method: "POST", body });
  if (!answer.ok) location.reload();
};

document.addEventListener("pointerup", dropped);
document.addEventListener("pointercancel", dropped);
