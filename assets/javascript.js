const tools = [
  {
    title: "Single Server with Active Directory",
    description: "Deploy a single server with Active Directory for simple on-premises scenarios.",
    toolUrl: "https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FJustinVerstijnen%2FJV-Azure-Deployment-Templates%2Frefs%2Fheads%2Fmain%2Fsingleserveractivedirectory%2Fmain.json",
    shortcut: "",
    github: "https://github.com/JustinVerstijnen/JV-Azure-Deployment-Templates/tree/main/singleserveractivedirectory",
    image: ""
  },
  {
    title: "Single Server with IIS",
    description: "Deploy a single server with IIS for simple on-premises scenarios.",
    toolUrl: "https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FJustinVerstijnen%2FJV-Azure-Deployment-Templates%2Frefs%2Fheads%2Fmain%2Fsingleserveriis%2Fmain.json",
    shortcut: "",
    github: "https://github.com/JustinVerstijnen/JV-Azure-Deployment-Templates/tree/main/singleserveriis",
    image: ""
  },
  {
    title: "Azure Virtual Desktop Kerberos",
    description: "Deploy a single session host with all Azure Virtual Desktop dependencies",
    toolUrl: "",
    shortcut: "",
    github: "",
    image: ""
  }
];

const grid = document.getElementById("toolsGrid");
const searchInput = document.getElementById("searchInput");
const emptyState = document.getElementById("emptyState");

function githubSvg() {
  return `<span class="github-icon" aria-hidden="true"><svg viewBox="0 0 24 24" width="20" height="20"><path fill="currentColor" d="M12 .5A12 12 0 0 0 8.2 23.9c.6.1.8-.3.8-.6v-2.1c-3.3.7-4-1.4-4-1.4-.5-1.3-1.3-1.7-1.3-1.7-1.1-.7.1-.7.1-.7 1.2.1 1.8 1.2 1.8 1.2 1.1 1.8 2.8 1.3 3.5 1 .1-.8.4-1.3.8-1.6-2.6-.3-5.4-1.3-5.4-5.9 0-1.3.5-2.4 1.2-3.2-.1-.3-.5-1.5.1-3.2 0 0 1-.3 3.3 1.2a11.4 11.4 0 0 1 6 0c2.3-1.5 3.3-1.2 3.3-1.2.6 1.7.2 2.9.1 3.2.8.8 1.2 1.9 1.2 3.2 0 4.6-2.8 5.6-5.4 5.9.4.4.8 1.1.8 2.2v3.2c0 .3.2.7.8.6A12 12 0 0 0 12 .5Z"/></svg></span>`;
}

function createToolCard(tool) {
  const article = document.createElement("article");
  article.className = "tool-card";
  article.innerHTML = `
    <a class="tool-image-link" href="${tool.toolUrl}" target="_blank" rel="noopener noreferrer" aria-label="Open ${tool.title}">
      <img class="tool-image" src="${tool.image}" alt="${tool.title} preview" loading="lazy" />
    </a>
    <div class="tool-content">
      <h2 class="tool-title">${tool.title}</h2>
      <p class="tool-description">${tool.description}</p>
      <div class="tool-actions">
        <a class="tool-primary" href="${tool.toolUrl}" target="_blank" rel="noopener noreferrer">Deploy</a>
        <a class="tool-github" href="${tool.github}" target="_blank" rel="noopener noreferrer">${githubSvg()} GitHub</a>
      </div>
      <a class="shortcut-link" href="${tool.shortcut}" target="_blank" rel="noopener noreferrer">${tool.shortcut.replace("https://", "")}</a>
    </div>
  `;
  return article;
}

function renderTools(query = "") {
  const search = query.trim().toLowerCase();
  const filtered = tools.filter((tool) => {
    return [tool.title, tool.description, tool.shortcut, tool.github]
      .join(" ")
      .toLowerCase()
      .includes(search);
  });

  grid.innerHTML = "";
  filtered.forEach((tool) => grid.appendChild(createToolCard(tool)));
  emptyState.style.display = filtered.length ? "none" : "block";
}

searchInput.addEventListener("input", (event) => renderTools(event.target.value));
renderTools();
