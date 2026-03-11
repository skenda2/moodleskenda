import exec from 'k6/execution';
import http from 'k6/http';
import { SharedArray } from 'k6/data';
import { check, fail, sleep } from 'k6';

const BASE_URL = (__ENV.K6_BASE_URL || 'http://web').replace(/\/$/, '');
const COURSE_PATH = __ENV.K6_COURSE_PATH || '/my/courses.php';
const THINK_TIME = Number(__ENV.K6_THINK_TIME || 1);
const LOGIN_EVERY_ITERATION = String(__ENV.K6_LOGIN_EVERY_ITERATION || 'false') === 'true';

function parseCsv(content) {
    const lines = content.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
    if (lines.length < 2) {
        return [];
    }

    const headers = lines[0].split(',').map((part) => part.trim());
    return lines.slice(1).map((line) => {
        const values = line.split(',').map((part) => part.trim());
        const row = {};
        headers.forEach((header, index) => {
            row[header] = values[index] || '';
        });
        return row;
    }).filter((row) => row.username && row.password);
}

const users = new SharedArray('moodle-users', () => {
    if (!__ENV.K6_USERS_CSV) {
        return [];
    }
    return parseCsv(open(__ENV.K6_USERS_CSV));
});

function getUser() {
    if (users.length > 0) {
        return users[(exec.vu.idInTest - 1) % users.length];
    }

    const username = __ENV.K6_USERNAME || __ENV.MOODLE_ADMIN_USER;
    const password = __ENV.K6_PASSWORD || __ENV.MOODLE_ADMIN_PASS;
    if (!username || !password) {
        fail('No test users configured. Provide loadtest/users.csv or K6_USERNAME/K6_PASSWORD.');
    }

    return { username, password };
}

function extractLoginToken(body) {
    const match = body.match(/name="logintoken"\s+value="([^"]+)"/i);
    if (!match) {
        fail('Unable to find logintoken on Moodle login page.');
    }
    return match[1];
}

function login(user) {
    const loginPage = http.get(`${BASE_URL}/login/index.php`, {
        tags: { name: 'login_page' },
    });

    check(loginPage, {
        'login page status 200': (response) => response.status === 200,
    });

    const payload = {
        anchor: '',
        logintoken: extractLoginToken(loginPage.body),
        username: user.username,
        password: user.password,
        rememberusername: 1,
    };

    const loginResponse = http.post(`${BASE_URL}/login/index.php`, payload, {
        redirects: 5,
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
        },
        tags: { name: 'login_post' },
    });

    const success = check(loginResponse, {
        'login request succeeded': (response) => response.status === 200,
        'login response not invalid': (response) => !/loginerrormessage|invalidlogin/i.test(response.body),
    });

    if (!success) {
        fail(`Login failed for user ${user.username}`);
    }
}

const vus = Number(__ENV.K6_VUS || 1);
const duration = __ENV.K6_DURATION || '30s';

export const options = {
    vus,
    duration,
    thresholds: {
        http_req_failed: ['rate<0.05'],
        http_req_duration: ['p(95)<5000'],
    },
};

let authenticated = false;

export default function() {
    const user = getUser();

    const health = http.get(`${BASE_URL}/healthz.php`, {
        tags: { name: 'healthz' },
    });
    check(health, {
        'health endpoint healthy': (response) => response.status === 200,
    });

    if (!authenticated || LOGIN_EVERY_ITERATION) {
        login(user);
        authenticated = true;
    }

    const dashboard = http.get(`${BASE_URL}/my/`, {
        tags: { name: 'dashboard' },
    });
    check(dashboard, {
        'dashboard status 200': (response) => response.status === 200,
    });

    const courses = http.get(`${BASE_URL}${COURSE_PATH}`, {
        tags: { name: 'courses' },
    });
    check(courses, {
        'courses status 200': (response) => response.status === 200,
    });

    sleep(THINK_TIME);
}
