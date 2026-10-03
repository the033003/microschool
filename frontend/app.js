async function getJSON(url) {
    const response = await fetch(url);

    if (!response.ok) {
        throw new Error(
            `Request failed: ${response.status}`
        );
    }

    return response.json();
}


async function loadDashboard() {
    try {
        const learners =
            await getJSON("/api/learners/");

        const pods =
            await getJSON("/api/pods/");

        const courses =
            await getJSON("/api/courses/");


        document.getElementById(
            "learner-count"
        ).textContent = learners.length;


        document.getElementById(
            "pod-count"
        ).textContent = pods.length;


        document.getElementById(
            "course-count"
        ).textContent = courses.length;


        renderLearners(learners);
        renderCourses(courses);

    } catch (error) {
        console.error(error);

        document.getElementById(
            "learners-list"
        ).textContent =
            "Unable to load learners.";

        document.getElementById(
            "courses-list"
        ).textContent =
            "Unable to load courses.";
    }
}


function renderLearners(learners) {
    const container =
        document.getElementById(
            "learners-list"
        );

    if (learners.length === 0) {
        container.innerHTML =
            "<p>No learners yet.</p>";

        return;
    }

    container.innerHTML = learners
        .map(
            learner => `
                <article class="list-item">
                    <strong>${learner.name}</strong>
                    <span>${learner.email}</span>
                </article>
            `
        )
        .join("");
}


function renderCourses(courses) {
    const container =
        document.getElementById(
            "courses-list"
        );

    if (courses.length === 0) {
        container.innerHTML =
            "<p>No courses yet.</p>";

        return;
    }

    container.innerHTML = courses
        .map(
            course => `
                <article class="list-item">
                    <strong>${course.title}</strong>
                    <span>
                        ${course.subject || "General"}
                    </span>
                </article>
            `
        )
        .join("");
}


loadDashboard();
