from prometheus_client import Counter

gandalf_requests = Counter('gandalf_requests', 'Total number of requests to /gandalf URI')
colombo_requests = Counter('colombo_requests', 'Total number of requests to /colombo URI')