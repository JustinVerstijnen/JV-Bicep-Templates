const repositoryOwner = "JustinVerstijnen";
const repositoryName = "AzureDeploymentTemplates";
const repositoryBranch = "main";
const rawTemplateBaseUrl = `https://raw.githubusercontent.com/${repositoryOwner}/${repositoryName}/refs/heads/${repositoryBranch}`;
const azurePortalTemplateBaseUrl = "https://portal.azure.com/#create/Microsoft.Template/uri/";
const deployToAzureButtonImageUrl = "https://aka.ms/deploytoazurebutton";

function getTemplateUrl(templatePath) {
  return `${rawTemplateBaseUrl}/${templatePath}`;
}

function getDeployToAzureUrl(templatePath) {
  return `${azurePortalTemplateBaseUrl}${encodeURIComponent(getTemplateUrl(templatePath))}`;
}

const tools = [
  {
    title: "Single Server with Active Directory",
    description: "Deploy a single Windows Server VM with Active Directory Domain Services and DNS. Estimated deployment time: 5 minutes.",
    templatePath: "singleserveractivedirectory/main.json",
    shortcut: "",
    image: `${rawTemplateBaseUrl}/singleserveractivedirectory/singleserveractivedirectory.png`
  },
  {
    title: "Single Server with IIS",
    description: "Deploy a single Windows Server VM with IIS and a default test website. Estimated deployment time: 5 minutes.",
    templatePath: "singleserveriis/main.json",
    shortcut: "",
    image: `${rawTemplateBaseUrl}/singleserveriis/singleserveriis.png`
  },
  {
    title: "Single Server with Active Directory and Workstation",
    description: "Deploy a Windows Server Active Directory domain controller and a Windows 11 workstation named vm-jv-ws01. Estimated deployment time: 5 minutes.",
    templatePath: "singleserveractivedirectoryworkstation/main.json",
    shortcut: "",
    image: `${rawTemplateBaseUrl}/singleserveractivedirectoryworkstation/singleserveractivedirectoryworkstation.png`
  },
  {
    title: "Azure Virtual Desktop Kerberos",
    description: "Deploy a single session host with all Azure Virtual Desktop dependencies. Estimated deployment time: 15 minutes.",
    templatePath: "azurevirtualdesktopkerberos/main.json",
    shortcut: "",
    image: `${rawTemplateBaseUrl}/azurevirtualdesktopkerberos/azurevirtualdesktopkerberos.png`
  },
  {
    title: "Azure Firewall with Three VNets",
    description: "Deploy Azure Firewall with a firewall policy, three VNets and full bidirectional VNet peering. Estimated deployment time: X minutes.",
    templatePath: "azurefirewallthreevnets/main.json",
    shortcut: "",
    image: `${rawTemplateBaseUrl}/azurefirewallthreevnets/azurefirewallthreevnets.png`
  }
];

const grid = document.getElementById("toolsGrid");
const searchInput = document.getElementById("searchInput");
const emptyState = document.getElementById("emptyState");

function createToolImage(tool, deployToAzureUrl) {
  if (!tool.image) {
    return "";
  }

  return `
    <a class="tool-image-link" href="${deployToAzureUrl}" target="_blank" rel="noopener noreferrer" aria-label="Deploy ${tool.title} to Azure">
      <img class="tool-image" src="${tool.image}" alt="${tool.title} preview" loading="lazy" />
    </a>
  `;
}

function createShortcutLink(tool) {
  if (!tool.shortcut) {
    return "";
  }

  return `<a class="shortcut-link" href="${tool.shortcut}" target="_blank" rel="noopener noreferrer">${tool.shortcut.replace("https://", "")}</a>`;
}

function createToolCard(tool) {
  const deployToAzureUrl = getDeployToAzureUrl(tool.templatePath);
  const article = document.createElement("article");
  article.className = "tool-card";
  article.innerHTML = `
    ${createToolImage(tool, deployToAzureUrl)}
    <div class="tool-content">
      <h2 class="tool-title">${tool.title}</h2>
      <p class="tool-description">${tool.description}</p>
      <div class="tool-actions">
        <a class="deploy-to-azure" href="${deployToAzureUrl}" target="_blank" rel="noopener noreferrer" aria-label="Deploy ${tool.title} to Azure">
          <img src="${deployToAzureButtonImageUrl}" alt="Deploy to Azure" loading="lazy" />
        </a>
      </div>
      ${createShortcutLink(tool)}
    </div>
  `;
  return article;
}

function renderTools(query = "") {
  const search = query.trim().toLowerCase();
  const filtered = tools.filter((tool) => {
    return [tool.title, tool.description, tool.shortcut, tool.templatePath]
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
