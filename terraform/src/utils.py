from datetime import datetime
import pytz

def get_colombo_time():
    colombo_tz = pytz.timezone('Asia/Colombo')
    return datetime.now(colombo_tz).strftime('%Y-%m-%d %H:%M:%S')