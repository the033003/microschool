const state = {
    token: localStorage.getItem("microschool_token"),
    user: null,
    page: "home",
    courses: [],
};


async function api(url, options = {}) {
    const headers = {
        ...(options.headers || {}),
    };

    if (state.token) {
        headers.Authorization = `Bearer ${state.token}`;
    }

    if (
        options.body &&
        typeof options.body !== "string"
    ) {
        headers["Content-Type"] = "application/json";
        options.body = JSON.stringify(options.body);
    }

    const response = await fetch(url, {
        ...options,
        headers,
    });

    if (!response.ok) {
        let message = "Something went wrong.";

        try {
            const data = await response.json();
            message = data.detail || message;
        } catch (_) {
            // Keep the default message.
        }

        throw new Error(message);
    }

    return response.json();
}


function escapeHTML(value) {
    return String(value ?? "")
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#039;");
}


function render() {
    if (!state.user) {
        renderAuth();
        return;
    }

    renderApp();
}


function renderAuth() {
    document.getElementById("app").innerHTML = `
        <main class="auth-page">
            <section class="auth-panel">
                <div class="brand-mark">M</div>

                <p class="eyebrow">MICROSCHOOL PLATFORM</p>

                <h1>Build a learning environment that fits your people.</h1>

                <p class="auth-intro">
                    A shared platform for learners, families, guides,
                    organizations, and the people who create resources.
                </p>

                <div class="auth-card">
                    <div class="auth-tabs">
                        <button
                            class="tab active"
                            data-auth-tab="login"
                        >
                            Sign in
                        </button>

                        <button
                            class="tab"
                            data-auth-tab="register"
                        >
                            Create account
                        </button>
                    </div>

                    <form id="auth-form">
                        <div id="auth-fields"></div>

                        <button
                            class="primary-button full-width"
                            type="submit"
                        >
                            <span id="auth-submit">Sign in</span>
                        </button>

                        <p
                            id="auth-error"
                            class="form-error"
                            hidden
                        ></p>
                    </form>
                </div>
            </section>
        </main>
    `;

    let mode = "login";

    const fields = document.getElementById("auth-fields");
    const tabs = document.querySelectorAll("[data-auth-tab]");
    const form = document.getElementById("auth-form");
    const submit = document.getElementById("auth-submit");
    const error = document.getElementById("auth-error");

    function updateForm() {
        tabs.forEach(tab => {
            tab.classList.toggle(
                "active",
                tab.dataset.authTab === mode
            );
        });

        if (mode === "login") {
            fields.innerHTML = `
                <label>
                    Email
                    <input
                        name="email"
                        type="email"
                        autocomplete="email"
                        required
                    >
                </label>

                <label>
                    Password
                    <input
                        name="password"
                        type="password"
                        autocomplete="current-password"
                        required
                    >
                </label>
            `;

            submit.textContent = "Sign in";
        } else {
            fields.innerHTML = `
                <label>
                    Name
                    <input
                        name="name"
                        type="text"
                        autocomplete="name"
                        required
                    >
                </label>

                <label>
                    Email
                    <input
                        name="email"
                        type="email"
                        autocomplete="email"
                        required
                    >
                </label>

                <label>
                    I am joining as
                    <select name="role">
                        <option value="learner">Learner</option>
                        <option value="parent">Parent</option>
                    </select>
                </label>

                <label>
                    Password
                    <input
                        name="password"
                        type="password"
                        autocomplete="new-password"
                        minlength="8"
                        required
                    >
                </label>
            `;

            submit.textContent = "Create account";
        }

        error.hidden = true;
    }

    tabs.forEach(tab => {
        tab.addEventListener("click", () => {
            mode = tab.dataset.authTab;
            updateForm();
        });
    });

    form.addEventListener("submit", async event => {
        event.preventDefault();

        const data = new FormData(form);
        error.hidden = true;
        submit.textContent = "Working...";

        try {
            if (mode === "login") {
                const body = new URLSearchParams();

                body.set("username", data.get("email"));
                body.set("password", data.get("password"));

                const result = await fetch(
                    "/api/auth/login",
                    {
                        method: "POST",
                        headers: {
                            "Content-Type":
                                "application/x-www-form-urlencoded",
                        },
                        body,
                    }
                );

                if (!result.ok) {
                    const payload = await result.json();
                    throw new Error(
                        payload.detail || "Unable to sign in."
                    );
                }

                const payload = await result.json();

                state.token = payload.access_token;
                state.user = payload.user;

                localStorage.setItem(
                    "microschool_token",
                    state.token
                );

                render();
                return;
            }

            const payload = await api(
                "/api/auth/register",
                {
                    method: "POST",
                    body: {
                        name: data.get("name"),
                        email: data.get("email"),
                        password: data.get("password"),
                        role: data.get("role"),
                    },
                }
            );

            const loginBody = new URLSearchParams();
            loginBody.set("username", data.get("email"));
            loginBody.set("password", data.get("password"));

            const loginResult = await fetch(
                "/api/auth/login",
                {
                    method: "POST",
                    headers: {
                        "Content-Type":
                            "application/x-www-form-urlencoded",
                    },
                    body: loginBody,
                }
            );

            if (!loginResult.ok) {
                throw new Error(
                    "Account created, but automatic sign-in failed."
                );
            }

            const loginPayload = await loginResult.json();

            state.token = loginPayload.access_token;
            state.user = loginPayload.user;

            localStorage.setItem(
                "microschool_token",
                state.token
            );

            render();
        } catch (err) {
            error.textContent = err.message;
            error.hidden = false;
            submit.textContent =
                mode === "login"
                    ? "Sign in"
                    : "Create account";
        }
    });

    updateForm();
}


function navigationForRole(role) {
    const base = [
        ["home", "Overview"],
        ["learning", "Learning"],
        ["resources", "Resources"],
    ];

    if (
        role === "guide" ||
        role === "organization_admin" ||
        role === "platform_admin"
    ) {
        base.push(["people", "People"]);
    }

    if (
        role === "organization_admin" ||
        role === "platform_admin"
    ) {
        base.push(["organization", "Organization"]);
    }

    return base;
}


function renderApp() {
    const navigation = navigationForRole(
        state.user.role
    );

    document.getElementById("app").innerHTML = `
        <div class="app-shell">
            <aside class="sidebar">
                <div class="sidebar-brand">
                    <div class="brand-mark small">M</div>

                    <div>
                        <strong>Microschool</strong>
                        <span>Platform</span>
                    </div>
                </div>

                <nav class="sidebar-nav">
                    ${navigation.map(([id, label]) => `
                        <button
                            class="nav-item ${
                                state.page === id
                                    ? "active"
                                    : ""
                            }"
                            data-page="${id}"
                        >
                            ${label}
                        </button>
                    `).join("")}
                </nav>

                <div class="sidebar-bottom">
                    <div class="user-mini">
                        <div class="avatar">
                            ${escapeHTML(
                                state.user.name
                                    .charAt(0)
                                    .toUpperCase()
                            )}
                        </div>

                        <div>
                            <strong>
                                ${escapeHTML(state.user.name)}
                            </strong>

                            <span>
                                ${formatRole(state.user.role)}
                            </span>
                        </div>
                    </div>

                    <button
                        class="logout-button"
                        id="logout"
                    >
                        Sign out
                    </button>
                </div>
            </aside>

            <div class="main-shell">
                <header class="topbar">
                    <div>
                        <span class="topbar-label">
                            ${pageLabel(state.page)}
                        </span>
                    </div>

                    <div class="topbar-user">
                        ${escapeHTML(state.user.email)}
                    </div>
                </header>

                <main class="content">
                    <div id="page-content"></div>
                </main>
            </div>
        </div>
    `;

    document
        .querySelectorAll("[data-page]")
        .forEach(button => {
            button.addEventListener("click", () => {
                state.page = button.dataset.page;
                renderApp();
            });
        });

    document
        .getElementById("logout")
        .addEventListener("click", logout);

    renderPage();
}


function pageLabel(page) {
    return {
        home: "Overview",
        learning: "Learning",
        resources: "Resources",
        people: "People",
        organization: "Organization",
    }[page] || "Microschool";
}


function formatRole(role) {
    return role
        .replaceAll("_", " ")
        .replace(/\b\w/g, letter =>
            letter.toUpperCase()
        );
}


async function renderPage() {
    const container =
        document.getElementById("page-content");

    if (state.page === "home") {
        renderHome(container);
        return;
    }

    if (state.page === "learning") {
        await renderLearning(container);
        return;
    }

    if (state.page === "resources") {
        renderResources(container);
        return;
    }

    if (state.page === "people") {
        await renderPeople(container);
        return;
    }

    if (state.page === "organization") {
        renderOrganization(container);
        return;
    }

    renderHome(container);
}


function renderHome(container) {
    const role = state.user.role;

    let heading = "Welcome back.";
    let description =
        "Your platform workspace is ready.";

    if (role === "learner") {
        heading = `Welcome back, ${escapeHTML(
            state.user.name
        )}.`;

        description =
            "Your learning workspace is where your current work, progress, and resources will come together.";
    }

    if (role === "parent") {
        heading = `Welcome, ${escapeHTML(
            state.user.name
        )}.`;

        description =
            "Your family workspace will bring together learning progress, schedules, resources, and communication.";
    }

    if (role === "guide") {
        heading = `Welcome, ${escapeHTML(
            state.user.name
        )}.`;

        description =
            "Your guide workspace will bring together pods, learners, attendance, assignments, and resources.";
    }

    container.innerHTML = `
        <section class="page-heading">
            <div>
                <p class="eyebrow">
                    ${formatRole(state.user.role)}
                </p>

                <h1>${heading}</h1>

                <p>${description}</p>
            </div>
        </section>

        <section class="dashboard-grid">
            <article class="dashboard-card">
                <span class="card-label">Learning</span>
                <h2>My learning</h2>
                <p>
                    Courses, activities, progress, and
                    the next things to work on.
                </p>

                <button
                    class="text-button"
                    data-page="learning"
                >
                    Open learning →
                </button>
            </article>

            <article class="dashboard-card">
                <span class="card-label">Resources</span>
                <h2>Resource library</h2>
                <p>
                    Reusable platform resources will live
                    here instead of being hardcoded into the app.
                </p>

                <button
                    class="text-button"
                    data-page="resources"
                >
                    Browse resources →
                </button>
            </article>

            <article class="dashboard-card">
                <span class="card-label">Account</span>
                <h2>Your workspace</h2>
                <p>
                    Signed in as
                    ${escapeHTML(state.user.email)}.
                </p>
            </article>
        </section>

        <section class="section-heading">
            <div>
                <p class="eyebrow">PLATFORM STATUS</p>
                <h2>Core platform</h2>
            </div>
        </section>

        <section class="status-grid">
            <div class="status-item">
                <span class="status-dot"></span>
                <div>
                    <strong>Identity</strong>
                    <span>Connected</span>
                </div>
            </div>

            <div class="status-item">
                <span class="status-dot"></span>
                <div>
                    <strong>Content system</strong>
                    <span>Foundation ready</span>
                </div>
            </div>

            <div class="status-item">
                <span class="status-dot"></span>
                <div>
                    <strong>Learning system</strong>
                    <span>Foundation ready</span>
                </div>
            </div>
        </section>
    `;

    container
        .querySelectorAll("[data-page]")
        .forEach(button => {
            button.addEventListener("click", () => {
                state.page = button.dataset.page;
                renderApp();
            });
        });
}


async function renderLearning(container) {
    container.innerHTML = `
        <section class="page-heading">
            <div>
                <p class="eyebrow">LEARNING</p>
                <h1>My learning</h1>
                <p>
                    Learning content will be supplied through
                    the platform's content system.
                </p>
            </div>
        </section>

        <section class="empty-panel">
            <div class="empty-icon">+</div>

            <h2>No learning assigned yet</h2>

            <p>
                Courses, units, lessons, activities, and
                assessments will appear here when they are
                provided by an organization or content creator.
            </p>
        </section>
    `;

    try {
        state.courses = await api("/api/courses/");

        if (state.courses.length === 0) {
            return;
        }

        container.querySelector(".empty-panel").outerHTML = `
            <section class="content-list">
                ${state.courses.map(course => `
                    <article class="content-card">
                        <div>
                            <span class="card-label">
                                ${escapeHTML(
                                    course.subject ||
                                    "Learning"
                                )}
                            </span>

                            <h2>
                                ${escapeHTML(course.title)}
                            </h2>

                            <p>
                                ${escapeHTML(
                                    course.description ||
                                    "No description provided."
                                )}
                            </p>
                        </div>

                        <button class="secondary-button">
                            Open
                        </button>
                    </article>
                `).join("")}
            </section>
        `;
    } catch (error) {
        container.querySelector(
            ".empty-panel"
        ).innerHTML = `
            <h2>Learning is temporarily unavailable</h2>
            <p>${escapeHTML(error.message)}</p>
        `;
    }
}


function renderResources(container) {
    container.innerHTML = `
        <section class="page-heading">
            <div>
                <p class="eyebrow">RESOURCE LIBRARY</p>
                <h1>Resources</h1>
                <p>
                    A shared home for guides, playbooks,
                    templates, articles, and other platform content.
                </p>
            </div>

            <button class="secondary-button">
                Browse all
            </button>
        </section>

        <section class="resource-grid">
            <article class="resource-card">
                <span class="resource-type">
                    Platform
                </span>
                <h2>Microschool resources</h2>
                <p>
                    Site-created guides and operational
                    resources will be published here.
                </p>
            </article>

            <article class="resource-card">
                <span class="resource-type">
                    Community
                </span>
                <h2>Community resources</h2>
                <p>
                    Approved resources created by
                    participating people and organizations.
                </p>
            </article>

            <article class="resource-card">
                <span class="resource-type">
                    Organization
                </span>
                <h2>Organization resources</h2>
                <p>
                    Private resources shared by your
                    organization.
                </p>
            </article>
        </section>
    `;
}


async function renderPeople(container) {
    container.innerHTML = `
        <section class="page-heading">
            <div>
                <p class="eyebrow">PEOPLE</p>
                <h1>Learners</h1>
                <p>
                    People connected to the guide or organization
                    workspace.
                </p>
            </div>
        </section>

        <section class="empty-panel" id="people-panel">
            <h2>Loading learners...</h2>
        </section>
    `;

    try {
        const learners =
            await api("/api/learners/");

        const panel =
            document.getElementById("people-panel");

        if (learners.length === 0) {
            panel.innerHTML = `
                <div class="empty-icon">+</div>
                <h2>No learners yet</h2>
                <p>
                    Learners will appear here when they
                    join an organization or pod.
                </p>
            `;

            return;
        }

        panel.outerHTML = `
            <section class="people-list">
                ${learners.map(learner => `
                    <article class="person-row">
                        <div class="avatar">
                            ${escapeHTML(
                                learner.name
                                    .charAt(0)
                                    .toUpperCase()
                            )}
                        </div>

                        <div>
                            <strong>
                                ${escapeHTML(learner.name)}
                            </strong>

                            <span>
                                ${escapeHTML(learner.email)}
                            </span>
                        </div>
                    </article>
                `).join("")}
            </section>
        `;
    } catch (error) {
        document.getElementById(
            "people-panel"
        ).innerHTML = `
            <h2>Unable to load learners</h2>
            <p>${escapeHTML(error.message)}</p>
        `;
    }
}


function renderOrganization(container) {
    container.innerHTML = `
        <section class="page-heading">
            <div>
                <p class="eyebrow">ORGANIZATION</p>
                <h1>Organization workspace</h1>
                <p>
                    Organization setup, members, pods,
                    permissions, and configuration will live here.
                </p>
            </div>
        </section>

        <section class="dashboard-grid">
            <article class="dashboard-card">
                <span class="card-label">Structure</span>
                <h2>Pods</h2>
                <p>
                    Create and manage the groups that make
                    up an organization.
                </p>
            </article>

            <article class="dashboard-card">
                <span class="card-label">People</span>
                <h2>Members</h2>
                <p>
                    Manage organization membership and roles.
                </p>
            </article>

            <article class="dashboard-card">
                <span class="card-label">Access</span>
                <h2>Permissions</h2>
                <p>
                    Control what different people can create,
                    manage, review, and publish.
                </p>
            </article>
        </section>
    `;
}


function logout() {
    state.token = null;
    state.user = null;
    localStorage.removeItem("microschool_token");
    render();
}


async function initialize() {
    if (!state.token) {
        render();
        return;
    }

    try {
        state.user = await api("/api/auth/me");
        render();
    } catch (_) {
        state.token = null;
        localStorage.removeItem("microschool_token");
        render();
    }
}


initialize();
