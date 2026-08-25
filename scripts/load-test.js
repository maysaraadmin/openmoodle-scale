import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '5m', target: 1000 },
    { duration: '10m', target: 10000 },
    { duration: '5m', target: 0 },
  ],
  thresholds: { http_req_duration: ['p(95)<2000'], http_req_failed: ['rate<0.05'] },
};

const baseUrl = __ENV.BASE_URL || 'https://moodle.openmoodle.local';

export default function () {
  const response = http.get(`${baseUrl}/login/index.php`);
  check(response, { 'login page loads': (result) => result.status === 200 });
  sleep(Math.random() * 3 + 1);
}