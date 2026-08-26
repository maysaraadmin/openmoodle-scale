import http from 'k6/http';
import { check, sleep, group } from 'k6';

export const options = {
  stages: [
    { duration: '2m', target: 500 },
    { duration: '5m', target: 2000 },
    { duration: '2m', target: 5000 },
    { duration: '5m', target: 5000 },
    { duration: '2m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000', 'p(99)<5000'],
    http_req_failed: ['rate<0.05'],
    'group_duration{group:::login}': ['p(95)<1500'],
    'group_duration{group:::course}': ['p(95)<2000'],
    'group_duration{group:::static}': ['p(95)<500'],
    'group_duration{group:::api}': ['p(95)<1000'],
  },
};

const baseUrl = __ENV.BASE_URL || 'https://moodle.openmoodle.local';

export default function () {
  group('login', () => {
    const res = http.get(`${baseUrl}/login/index.php`);
    check(res, {
      'login page loads': (r) => r.status === 200,
      'login has form': (r) => r.body.includes('loginguestbtn') || r.body.includes('login'),
    });
    sleep(1);
  });

  group('course', () => {
    const res = http.get(`${baseUrl}/course/`);
    check(res, {
      'course page loads': (r) => r.status === 200 || r.status === 302,
    });
    sleep(1);
  });

  group('static', () => {
    const staticUrls = [
      '/lib/jquery/jquery-3.6.0.min.js',
      '/lib/bootstrap/js/bootstrap.bundle.min.js',
      '/theme/boost/pix/favicon.ico',
    ];

    staticUrls.forEach((path) => {
      const res = http.get(`${baseUrl}${path}`);
      check(res, {
        [`${path} loads`]: (r) => r.status === 200,
        [`${path} cached`]: (r) => r.headers['cache-control'] && r.headers['cache-control'].includes('max-age'),
      });
    });
    sleep(0.5);
  });

  group('api', () => {
    const res = http.get(`${baseUrl}/lib/ajax/service-nologin.php?sesskey=test&info=core_get_string&string=fullname`);
    check(res, {
      'api responds': (r) => r.status === 200 || r.status === 403,
    });
    sleep(0.2);
  });

  sleep(Math.random() * 1 + 0.5);
}
