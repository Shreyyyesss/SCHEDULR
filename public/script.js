const form = document.getElementById("scheduleForm");
const refreshBtn = document.getElementById("refreshBtn");
const findSlotBtn = document.getElementById("findSlotBtn");
const responseBox = document.createElement("div");
responseBox.className = "response";
document.querySelector(".card").appendChild(responseBox);
const tableContainer = document.createElement("div");
document.querySelector(".card").appendChild(tableContainer);

// 🧾 Submit availability
form.addEventListener("submit", async (e) => {
  e.preventDefault();
  const name = document.getElementById("name").value.trim();
  const start = parseFloat(document.getElementById("start").value);
  const end = parseFloat(document.getElementById("end").value);

  responseBox.textContent = "⏳ Saving...";
  try {
    const res = await fetch("/schedule", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name, start, end }),
    });
    const data = await res.json();
    responseBox.textContent = data.message || "✅ Saved!";
    form.reset();
  } catch (err) {
    responseBox.textContent = "❌ Error saving availability";
    console.error(err);
  }
});

// 🔄 View all
refreshBtn.addEventListener("click", async () => {
  responseBox.textContent = "⏳ Loading...";
  try {
    const res = await fetch("/availabilities");
    const data = await res.json();

    if (data.length === 0) {
      tableContainer.innerHTML = "<p>No availabilities saved yet.</p>";
      responseBox.textContent = "";
      return;
    }

    const table = `
      <table>
        <tr><th>Name</th><th>Start</th><th>End</th></tr>
        ${data
          .map(
            (row) =>
              `<tr><td>${row.name}</td><td>${row.start}</td><td>${row.end}</td></tr>`
          )
          .join("")}
      </table>`;
    tableContainer.innerHTML = table;
    responseBox.textContent = "✅ Availabilities loaded!";
  } catch (err) {
    responseBox.textContent = "❌ Error loading data";
    console.error(err);
  }
});

// 🕒 Find best slot
findSlotBtn.addEventListener("click", async () => {
  responseBox.textContent = "⏳ Finding best slot...";
  try {
    const res = await fetch("/find-best-slot");
    const data = await res.json();

    if (!data.result || Object.keys(data.result).length === 0) {
      responseBox.textContent = "⚠️ No suitable slot found!";
      return;
    }

    const { BestStart, Count, People } = data.result;
    responseBox.textContent = `✅ Best Slot: ${BestStart} hrs (${Count} people) → ${People}`;
  } catch (err) {
    responseBox.textContent = "❌ Error finding best slot";
    console.error(err);
  }
});
