import time
import hashlib
import json
import os
import sys
import traceback
from datetime import datetime
import warnings
import urllib3
import ssl
import atexit

# Disable all SSL warnings
urllib3.disable_warnings()
warnings.filterwarnings('ignore')

# Create an unverified SSL context
ssl._create_default_https_context = ssl._create_unverified_context

import undetected_chromedriver as uc
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

# Global driver instance
driver = None

class ResponseCollector:
    def __init__(self):
        self.messages = []
        self.error = None
        self.status = None
        self.data = None
        self.auth_state = None
        self.challenge_url = None  # New field to store 2FA challenge URL

    def add_message(self, message):
        self.messages.append(message)

    def set_error(self, error):
        self.error = error

    def set_status(self, status):
        self.status = status

    def set_data(self, data):
        self.data = data

    def set_auth_state(self, state):
        self.auth_state = state

    def set_challenge_url(self, url):
        self.challenge_url = url

    def to_json(self):
        response = {
            'messages': self.messages
        }
        if self.error:
            response['error'] = self.error
        if self.status:
            response['status'] = self.status
        if self.data:
            response.update(self.data)
        if self.auth_state:
            response['auth_state'] = self.auth_state
        if self.challenge_url:
            response['challenge_url'] = self.challenge_url
        return json.dumps(response)

def compute_sapisidhash(sapisid_value: str,
                        origin: str = "https://studio.youtube.com") -> str:
    ts = int(time.time())
    to_hash = f"{ts} {sapisid_value} {origin}"
    digest = hashlib.sha1(to_hash.encode("utf-8")).hexdigest()
    return f"{ts}_{digest}"

def load_cookies():
    cookie_file = os.path.join(os.path.dirname(__file__), 'youtube_cookies.json')
    if os.path.exists(cookie_file):
        try:
            with open(cookie_file, 'r') as f:
                return json.load(f)
        except Exception as e:
            print(f"Error loading cookies: {str(e)}")
            return None
    return None

def save_cookies(cookies):
    cookie_file = os.path.join(os.path.dirname(__file__), 'youtube_cookies.json')
    try:
        with open(cookie_file, 'w') as f:
            json.dump(cookies, f)
    except Exception as e:
        print(f"Error saving cookies: {str(e)}")

def load_challenge_url():
    url_file = os.path.join(os.path.dirname(__file__), 'challenge_url.txt')
    if os.path.exists(url_file):
        try:
            with open(url_file, 'r') as f:
                return f.read().strip()
        except Exception as e:
            print(f"Error loading challenge URL: {str(e)}")
            return None
    return None

def save_challenge_url(url):
    url_file = os.path.join(os.path.dirname(__file__), 'challenge_url.txt')
    try:
        with open(url_file, 'w') as f:
            f.write(url)
    except Exception as e:
        print(f"Error saving challenge URL: {str(e)}")

def get_driver(headless: bool = True):
    global driver
    if driver is None:
        options = uc.ChromeOptions()
        options.headless = headless
        options.add_argument("--disable-blink-features=AutomationControlled")
        options.add_argument("--no-sandbox")
        options.add_argument("--ignore-certificate-errors")
        options.add_argument("--ignore-ssl-errors")
        
        # Add user data directory for session persistence
        user_data_dir = os.path.join(os.path.dirname(__file__), 'chrome_profile')
        options.add_argument(f'--user-data-dir={user_data_dir}')
        
        # Add these options to help maintain the session
        options.add_argument('--disable-dev-shm-usage')
        options.add_argument('--disable-gpu')
        options.add_argument('--no-first-run')
        options.add_argument('--no-service-autorun')
        options.add_argument('--password-store=basic')
        options.add_argument('--use-mock-keychain')
        
        driver = uc.Chrome(options=options)
        
        # Load saved cookies if they exist
        cookies = load_cookies()
        if cookies:
            driver.get("https://youtube.com")  # Need to be on the domain to set cookies
            for cookie in cookies:
                try:
                    # Ensure cookie domain is set correctly
                    if 'domain' in cookie:
                        cookie['domain'] = '.youtube.com'
                    driver.add_cookie(cookie)
                except Exception as e:
                    # Don't print error, just continue
                    pass
    return driver

def check_auth_state():
    """Check the current authentication state of the browser session"""
    response = ResponseCollector()
    try:
        driver = get_driver(headless=True)
        
        # First try the saved challenge URL if it exists
        challenge_url = load_challenge_url()
        if challenge_url:
            print(f"Found saved challenge URL: {challenge_url}")  # Debug log
            driver.get(challenge_url)
            time.sleep(2)
            if "challenge" in driver.current_url or "2fa" in driver.current_url.lower():
                print("Detected 2FA challenge page")  # Debug log
                response.set_auth_state('2FA_REQUIRED')
                response.set_challenge_url(driver.current_url)
                save_challenge_url(driver.current_url)
                return response.to_json()
        
        # If no challenge URL or it didn't work, try studio.youtube.com
        print("Checking studio.youtube.com")  # Debug log
        driver.get("https://studio.youtube.com")
        time.sleep(2)
        
        current_url = driver.current_url
        print(f"Current URL: {current_url}")  # Debug log
        
        if "accounts.google.com" in current_url:
            if "challenge" in current_url or "2fa" in current_url.lower():
                print("Detected 2FA challenge page")  # Debug log
                response.set_auth_state('2FA_REQUIRED')
                response.set_challenge_url(current_url)
                save_challenge_url(current_url)
            else:
                print("Detected login required")  # Debug log
                response.set_auth_state('LOGIN_REQUIRED')
        else:
            print("Detected already authenticated")  # Debug log
            response.set_auth_state('AUTHENTICATED')
            
            # If authenticated, fetch the data
            try:
                # Extract cookies and compute Authorization
                cdp = driver.execute_cdp_cmd('Network.getAllCookies', {})
                cookies = cdp.get('cookies', [])
                save_cookies(cookies)
                
                # Find SAPISID cookie
                sapisid = None
                for cookie in cookies:
                    if cookie['name'] == 'SAPISID':
                        sapisid = cookie['value']
                        break
                        
                if not sapisid:
                    raise RuntimeError('Missing SAPISID cookie')
                    
                fresh_hash = compute_sapisidhash(sapisid)
                cookie_str = '; '.join([f"{c['name']}={c['value']}" for c in cookies])
                auth_value = f"SAPISIDHASH {fresh_hash}"

                # Load request bodies from JSON files
                video_list_body = load_request_body('video_list_body.json')
                views_body = load_request_body('views_body.json')
                
                if not video_list_body or not views_body:
                    raise RuntimeError('Failed to load request bodies')

                # Fetch video list
                fetch_videos_script = f"""
                const body = {json.dumps(video_list_body)};
                const done = arguments[arguments.length - 1];
                fetch('https://studio.youtube.com/youtubei/v1/creator/list_creator_videos?alt=json', {{
                    method: 'POST',
                    credentials: 'include',
                    headers: {{
                        'Content-Type': 'application/json',
                        'Authorization': '{auth_value}',
                        'Cookie': '{cookie_str}',
                        'x-goog-authuser': '0',
                        'x-origin': 'https://studio.youtube.com'
                    }},
                    body: JSON.stringify(body)
                }})
                .then(r => r.text().then(txt => done({{status: r.status, text: txt}})))
                .catch(err => done({{error: err.toString()}}));
                """

                videos_result = driver.execute_async_script(fetch_videos_script)
                if 'error' in videos_result:
                    raise RuntimeError('Browser fetch error for videos: ' + videos_result['error'])
                if videos_result.get('status') != 200:
                    raise RuntimeError(f"Unexpected status for videos {videos_result['status']}: {videos_result.get('text')}")

                videos_data = json.loads(videos_result['text'])
                print(f"API Response: {json.dumps(videos_data, indent=2)}")  # Add debug logging
                all_data = {'videos': [], 'views': {}}

                # Process each video
                for video in videos_data.get('videos', []):
                    video_id = video.get('videoId')
                    if not video_id:
                        continue

                    # Add video data
                    video_data = {
                        'youtube_id': video_id,
                        'title': video.get('title', ''),
                        'description': video.get('description', ''),
                        'date_published': video.get('timePublishedSeconds', ''),
                        'channel_id': video.get('channelId', ''),
                        'draft_status': video.get('draftStatus', ''),
                        'length_seconds': video.get('lengthSeconds', ''),
                        'time_created_seconds': video.get('timeCreatedSeconds', ''),
                        'watch_url': video.get('watchUrl', ''),
                        'user_set_monetization': video.get('monetization', {}).get('adMonetization', {}).get('userSetMonetization', ''),
                        'ad_friendly_review_decision': video.get('selfCertification', {}).get('adFriendlyReviewDecision', ''),
                        'view_count': video.get('publicMetrics', {}).get('viewCount', ''),
                        'comment_count': video.get('publicMetrics', {}).get('commentCount', ''),
                        'like_count': video.get('publicMetrics', {}).get('likeCount', ''),
                        'external_view_count': video.get('publicMetrics', {}).get('externalViewCount', ''),
                        'is_shorts_renderable': video.get('shorts', {}).get('isShortsRenderable', False)
                    }
                    all_data['videos'].append(video_data)

                    # Update views body with current video ID
                    views_body['screenConfig']['entity']['videoId'] = video_id
                    print(f"Debug - Updated views body with video ID: {video_id}")

                    # Request views for this video
                    fetch_views_script = f"""
                    const body = {json.dumps(views_body)};
                    const done = arguments[arguments.length - 1];
                    fetch('https://studio.youtube.com/youtubei/v1/yta_web/get_screen?alt=json', {{
                        method: 'POST',
                        credentials: 'include',
                        headers: {{
                            'Content-Type': 'application/json',
                            'Authorization': '{auth_value}',
                            'Cookie': '{cookie_str}',
                            'x-goog-authuser': '0',
                            'x-origin': 'https://studio.youtube.com'
                        }},
                        body: JSON.stringify(body)
                    }})
                    .then(r => r.text().then(txt => done({{status: r.status, text: txt}})))
                    .catch(err => done({{error: err.toString()}}));
                    """

                    views_result = driver.execute_async_script(fetch_views_script)
                    if 'error' in views_result:
                        response.add_message(f"Error fetching views for video {video_id}: {views_result['error']}")
                        continue
                    if views_result.get('status') != 200:
                        response.add_message(f"Unexpected status for video {video_id}: {views_result['status']}")
                        continue

                    # Process views data
                    views_data = json.loads(views_result['text'])
                    external_views_data = views_data['cards'][1]['keyMetricCardData']['keyMetricTabs'][0]['primaryContent']['mainSeries']['datums']
                    
                    # Convert timestamps to dates and store views
                    views = []
                    for datum in external_views_data:
                        timestamp = datum['x']
                        date = datetime.fromtimestamp(timestamp / 1000).strftime('%Y-%m-%d')
                        views.append({
                            'date': date,
                            'millis_data': timestamp,
                            'daily_view_count': datum['y']
                        })
                    # Sort views by date before returning
                    views.sort(key=lambda x: x['millis_data'])
                    
                    # Store views using the video_id from the API response
                    all_data['views'][video_id] = views
                    print(f"Debug - Stored views for video {video_id}: {len(views)} data points")

                    # Small delay between requests
                    time.sleep(1)

                response.set_data({'videos': all_data['videos'], 'views': all_data['views']})
            except Exception as e:
                print(f"Error fetching data: {str(e)}")  # Debug log
                print(f"Error type: {type(e)}")  # Print error type
                print(f"Full error details: {traceback.format_exc()}")  # Print full traceback
                response.add_message(f"Error fetching data: {str(e)}")
            
        print(f"Final auth state: {response.auth_state}")  # Debug log
        return response.to_json()
    except Exception as e:
        print(f"Error in check_auth_state: {str(e)}")  # Debug log
        response.set_error(f"Error checking auth state: {str(e)}")
        return response.to_json()

def fetch_youtube_data(username: str = None, password: str = None, two_fa_code: str = None, headless: bool = True) -> dict:
    response = ResponseCollector()

    try:
        driver = get_driver(headless=headless)
        wait = WebDriverWait(driver, 30)

        # If we have a 2FA code, try to use the saved challenge URL first
        if two_fa_code:
            challenge_url = load_challenge_url()
            if challenge_url:
                print(f"Using saved challenge URL: {challenge_url}")
                driver.get(challenge_url)
                time.sleep(2)
                try:
                    wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, 'input[type="tel"]')))
                    driver.find_element(By.CSS_SELECTOR, 'input[type="tel"]').send_keys(two_fa_code)
                    driver.find_element(By.CSS_SELECTOR, '#idvPreregisteredPhoneNext').click()
                    time.sleep(3)
                    response.set_auth_state('AUTHENTICATED')
                except Exception as e:
                    print(f"Error during 2FA input: {str(e)}")
                    response.set_auth_state('2FA_REQUIRED')
                    response.set_challenge_url(driver.current_url)
                    save_challenge_url(driver.current_url)
                    return response.to_json()

        # First check if we're already logged in
        driver.get("https://studio.youtube.com")
        time.sleep(2)
        
        # If we're already logged in, we'll be redirected to studio.youtube.com
        if "accounts.google.com" not in driver.current_url:
            print("Already logged in, proceeding with data fetch...")
            response.set_auth_state('AUTHENTICATED')
        else:
            # Check if we're at the 2FA page
            current_url = driver.current_url
            if "challenge" in current_url or "2fa" in current_url.lower():
                if two_fa_code:
                    try:
                        wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, 'input[type="tel"]')))
                        driver.find_element(By.CSS_SELECTOR, 'input[type="tel"]').send_keys(two_fa_code)
                        driver.find_element(By.CSS_SELECTOR, '#idvPreregisteredPhoneNext').click()
                        time.sleep(3)
                        response.set_auth_state('AUTHENTICATED')
                    except Exception as e:
                        print(f"Error during 2FA input: {str(e)}")
                        response.set_auth_state('2FA_REQUIRED')
                        response.set_challenge_url(driver.current_url)
                        save_challenge_url(driver.current_url)
                        return response.to_json()
                else:
                    response.set_auth_state('2FA_REQUIRED')
                    response.set_challenge_url(current_url)
                    save_challenge_url(current_url)
                    return response.to_json()
            else:
                # Only proceed with login if we're not already at 2FA
                if not username or not password:
                    response.set_auth_state('LOGIN_REQUIRED')
                    return response.to_json()
                    
                driver.get("https://accounts.google.com/signin")
                time.sleep(2)

                # Enter email
                wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, 'input[type="email"]')))
                driver.find_element(By.CSS_SELECTOR, 'input[type="email"]').send_keys(username)
                driver.find_element(By.CSS_SELECTOR, '#identifierNext').click()

                # Enter password
                wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, 'input[type="password"]')))
                driver.find_element(By.CSS_SELECTOR, 'input[type="password"]').send_keys(password)
                driver.find_element(By.CSS_SELECTOR, '#passwordNext').click()

                # Check for 2FA prompt
                try:
                    wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, 'input[type="tel"]')))
                    if two_fa_code:
                        driver.find_element(By.CSS_SELECTOR, 'input[type="tel"]').send_keys(two_fa_code)
                        driver.find_element(By.CSS_SELECTOR, '#idvPreregisteredPhoneNext').click()
                        time.sleep(3)
                        response.set_auth_state('AUTHENTICATED')
                    else:
                        response.set_auth_state('2FA_REQUIRED')
                        response.set_challenge_url(driver.current_url)
                        save_challenge_url(driver.current_url)
                        return response.to_json()
                except:
                    response.set_auth_state('AUTHENTICATED')
                    pass  # No 2FA needed

        # If we're not authenticated, return early
        if response.auth_state != 'AUTHENTICATED':
            return response.to_json()

        # Wait for login to complete
        time.sleep(3)

        # Navigate to YouTube Studio
        driver.get("https://studio.youtube.com")
        wait.until(EC.url_contains("studio.youtube.com"))
        time.sleep(3)

        # Ensure root-domain cookies
        driver.get("https://youtube.com")
        wait.until(lambda d: "youtube.com" in d.current_url)
        driver.get("https://studio.youtube.com")
        time.sleep(2)

        # Extract cookies and compute Authorization
        cdp = driver.execute_cdp_cmd('Network.getAllCookies', {})
        cookies = cdp.get('cookies', [])
        save_cookies(cookies)
        
        # Find SAPISID cookie
        sapisid = None
        for cookie in cookies:
            if cookie['name'] == 'SAPISID':
                sapisid = cookie['value']
                break
                
        if not sapisid:
            raise RuntimeError('Missing SAPISID cookie')
            
        fresh_hash = compute_sapisidhash(sapisid)
        cookie_str = '; '.join([f"{c['name']}={c['value']}" for c in cookies])
        auth_value = f"SAPISIDHASH {fresh_hash}"

        # Load request bodies from JSON files
        video_list_body = load_request_body('video_list_body.json')
        views_body = load_request_body('views_body.json')
        
        if not video_list_body or not views_body:
            raise RuntimeError('Failed to load request bodies')

        # Fetch video list
        fetch_videos_script = f"""
        const body = {json.dumps(video_list_body)};
        const done = arguments[arguments.length - 1];
        fetch('https://studio.youtube.com/youtubei/v1/creator/list_creator_videos?alt=json', {{
            method: 'POST',
            credentials: 'include',
            headers: {{
                'Content-Type': 'application/json',
                'Authorization': '{auth_value}',
                'Cookie': '{cookie_str}',
                'x-goog-authuser': '0',
                'x-origin': 'https://studio.youtube.com'
            }},
            body: JSON.stringify(body)
        }})
        .then(r => r.text().then(txt => done({{status: r.status, text: txt}})))
        .catch(err => done({{error: err.toString()}}));
        """

        videos_result = driver.execute_async_script(fetch_videos_script)
        if 'error' in videos_result:
            raise RuntimeError('Browser fetch error for videos: ' + videos_result['error'])
        if videos_result.get('status') != 200:
            raise RuntimeError(f"Unexpected status for videos {videos_result['status']}: {videos_result.get('text')}")

        videos_data = json.loads(videos_result['text'])
        print(f"API Response: {json.dumps(videos_data, indent=2)}")  # Add debug logging
        all_data = {'videos': [], 'views': {}}

        # Process each video
        for video in videos_data.get('videos', []):
            video_id = video.get('videoId')
            if not video_id:
                continue

            # Add video data
            video_data = {
                'youtube_id': video_id,
                'title': video.get('title', ''),
                'description': video.get('description', ''),
                'date_published': video.get('timePublishedSeconds', ''),
                'channel_id': video.get('channelId', ''),
                'draft_status': video.get('draftStatus', ''),
                'length_seconds': video.get('lengthSeconds', ''),
                'time_created_seconds': video.get('timeCreatedSeconds', ''),
                'watch_url': video.get('watchUrl', ''),
                'user_set_monetization': video.get('monetization', {}).get('adMonetization', {}).get('userSetMonetization', ''),
                'ad_friendly_review_decision': video.get('selfCertification', {}).get('adFriendlyReviewDecision', ''),
                'view_count': video.get('publicMetrics', {}).get('viewCount', ''),
                'comment_count': video.get('publicMetrics', {}).get('commentCount', ''),
                'like_count': video.get('publicMetrics', {}).get('likeCount', ''),
                'external_view_count': video.get('publicMetrics', {}).get('externalViewCount', ''),
                'is_shorts_renderable': video.get('shorts', {}).get('isShortsRenderable', False)
            }
            all_data['videos'].append(video_data)

            # Update views body with current video ID
            views_body['screenConfig']['entity']['videoId'] = video_id
            print(f"Debug - Updated views body with video ID: {video_id}")

            # Request views for this video
            fetch_views_script = f"""
            const body = {json.dumps(views_body)};
            const done = arguments[arguments.length - 1];
            fetch('https://studio.youtube.com/youtubei/v1/yta_web/get_screen?alt=json', {{
                method: 'POST',
                credentials: 'include',
                headers: {{
                    'Content-Type': 'application/json',
                    'Authorization': '{auth_value}',
                    'Cookie': '{cookie_str}',
                    'x-goog-authuser': '0',
                    'x-origin': 'https://studio.youtube.com'
                }},
                body: JSON.stringify(body)
            }})
            .then(r => r.text().then(txt => done({{status: r.status, text: txt}})))
            .catch(err => done({{error: err.toString()}}));
            """

            views_result = driver.execute_async_script(fetch_views_script)
            if 'error' in views_result:
                response.add_message(f"Error fetching views for video {video_id}: {views_result['error']}")
                continue
            if views_result.get('status') != 200:
                response.add_message(f"Unexpected status for video {video_id}: {views_result['status']}")
                continue

            # Process views data
            views_data = json.loads(views_result['text'])
            external_views_data = views_data['cards'][1]['keyMetricCardData']['keyMetricTabs'][0]['primaryContent']['mainSeries']['datums']
            
            # Convert timestamps to dates and store views
            views = []
            for datum in external_views_data:
                timestamp = datum['x']
                date = datetime.fromtimestamp(timestamp / 1000).strftime('%Y-%m-%d')
                views.append({
                    'date': date,
                    'millis_data': timestamp,
                    'daily_view_count': datum['y']
                })
            # Sort views by date before returning
            views.sort(key=lambda x: x['millis_data'])
            
            # Store views using the video_id from the API response
            all_data['views'][video_id] = views
            print(f"Debug - Stored views for video {video_id}: {len(views)} data points")
            print(f"Debug - Current views data structure: {all_data['views']}")

            # Small delay between requests
            time.sleep(1)

        response.set_data({'videos': all_data['videos'], 'views': all_data['views']})
        return response.to_json()

    except Exception as e:
        error_msg = f"Error: {str(e)}\n{traceback.format_exc()}"
        response.set_error(error_msg)
        return response.to_json()

def load_request_body(filename):
    """Load a request body from a JSON file"""
    file_path = os.path.join(os.path.dirname(__file__), 'request_body', filename)
    try:
        with open(file_path, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading request body from {filename}: {str(e)}")
        return None

if __name__ == '__main__':
    try:
        # If no arguments provided, just check auth state
        if len(sys.argv) == 1:
            result = check_auth_state()
            # Only print the JSON response
            print(result)
            sys.exit(0)
            
        # Otherwise, proceed with normal flow
        if len(sys.argv) < 3:
            response = ResponseCollector()
            response.set_error('Usage: python youtube_scraper.py <username> <password> [2fa_code]')
            print(response.to_json())
            sys.exit(1)
        
        username = sys.argv[1]
        password = sys.argv[2]
        two_fa_code = sys.argv[3] if len(sys.argv) > 3 else None
        
        result = fetch_youtube_data(username, password, two_fa_code)
        # Only print the JSON response
        print(result)
    except Exception as e:
        response = ResponseCollector()
        response.set_error(f'Main execution failed: {str(e)}')
        # Only print the JSON response
        print(response.to_json())
        sys.exit(1) 