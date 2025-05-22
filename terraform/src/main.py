from flask import Flask, render_template
from prometheus_client import generate_latest
from datetime import datetime
import pytz
from metrics import gandalf_requests, colombo_requests

# Initialize Flask app
app = Flask(__name__)

# Routes
@app.route('/')
def home():
    gandalf_requests.inc()
    colombo_requests.inc()
    image_url = "https://static1.colliderimages.com/wordpress/wp-content/uploads/2024/10/why-gandalf-needs-a-staff-in-the-lord-of-the-rings.jpg"
    colombo_time = get_colombo_time()
    return render_template('index.html', image_url=image_url, colombo_time=colombo_time)

@app.route('/metrics')
def metrics():
    return generate_latest()

# Utility functions
def get_colombo_time():
    colombo_tz = pytz.timezone('Asia/Colombo')
    return datetime.now(colombo_tz).strftime('%Y-%m-%d %H:%M:%S')

# Main entry point
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)