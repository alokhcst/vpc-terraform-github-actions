# lambda_function.py
import json
import urllib.request
import urllib.parse
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    AWS Lambda function to get geolocation information based on IP address
    """
    try:
        # Log the incoming event
        logger.info(f"Received event: {json.dumps(event)}")
        
        # Parse the request body
        if 'body' in event and event['body']:
            body = json.loads(event['body'])
        else:
            body = {}
        
        # Get IP address from request body or use source IP
        ip_address = body.get('ip')
        if not ip_address:
            # Get IP from the request context
            ip_address = event.get('requestContext', {}).get('identity', {}).get('sourceIp', '8.8.8.8')
        
        logger.info(f"Looking up geolocation for IP: {ip_address}")
        
        # Get geolocation data
        geo_data = get_geolocation(ip_address)
        
        # Prepare response
        response_body = {
            'success': True,
            'ip': ip_address,
            'location': geo_data,
            'message': 'Geolocation retrieved successfully'
        }
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type'
            },
            'body': json.dumps(response_body)
        }
        
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}")
        
        error_response = {
            'success': False,
            'error': str(e),
            'message': 'Failed to retrieve geolocation'
        }
        
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type'
            },
            'body': json.dumps(error_response)
        }

def get_geolocation(ip_address):
    """
    Get geolocation information for the given IP address using a free API
    """
    try:
        # Use ip-api.com (free tier allows 1000 requests per month)
        url = f"http://ip-api.com/json/{ip_address}?fields=status,message,country,countryCode,region,regionName,city,zip,lat,lon,timezone,isp,org,as,query"
        
        logger.info(f"Making request to: {url}")
        
        # Make HTTP request
        with urllib.request.urlopen(url, timeout=10) as response:
            data = response.read()
            geo_info = json.loads(data.decode('utf-8'))
        
        logger.info(f"API response: {geo_info}")
        
        # Check if the request was successful
        if geo_info.get('status') == 'success':
            return {
                'country': geo_info.get('country', 'Unknown'),
                'country_code': geo_info.get('countryCode', 'Unknown'),
                'region': geo_info.get('regionName', 'Unknown'),
                'region_code': geo_info.get('region', 'Unknown'),
                'city': geo_info.get('city', 'Unknown'),
                'zip_code': geo_info.get('zip', 'Unknown'),
                'latitude': geo_info.get('lat', 0),
                'longitude': geo_info.get('lon', 0),
                'timezone': geo_info.get('timezone', 'Unknown'),
                'isp': geo_info.get('isp', 'Unknown'),
                'organization': geo_info.get('org', 'Unknown'),
                'as_info': geo_info.get('as', 'Unknown')
            }
        else:
            # API returned an error
            error_msg = geo_info.get('message', 'Unknown error from geolocation API')
            raise Exception(f"Geolocation API error: {error_msg}")
            
    except urllib.error.URLError as e:
        logger.error(f"URL error: {str(e)}")
        raise Exception(f"Network error while fetching geolocation: {str(e)}")
    
    except json.JSONDecodeError as e:
        logger.error(f"JSON decode error: {str(e)}")
        raise Exception(f"Invalid response from geolocation API: {str(e)}")
    
    except Exception as e:
        logger.error(f"Unexpected error in get_geolocation: {str(e)}")
        raise Exception(f"Failed to get geolocation: {str(e)}")

# Alternative function using ipinfo.io (requires token for production)
def get_geolocation_ipinfo(ip_address, token=None):
    """
    Alternative geolocation function using ipinfo.io
    """
    try:
        base_url = "https://ipinfo.io"
        if token:
            url = f"{base_url}/{ip_address}/json?token={token}"
        else:
            url = f"{base_url}/{ip_address}/json"
        
        with urllib.request.urlopen(url, timeout=10) as response:
            data = response.read()
            geo_info = json.loads(data.decode('utf-8'))
        
        # Parse location coordinates
        loc = geo_info.get('loc', '0,0').split(',')
        lat = float(loc[0]) if len(loc) > 0 else 0
        lon = float(loc[1]) if len(loc) > 1 else 0
        
        return {
            'country': geo_info.get('country', 'Unknown'),
            'region': geo_info.get('region', 'Unknown'),
            'city': geo_info.get('city', 'Unknown'),
            'zip_code': geo_info.get('postal', 'Unknown'),
            'latitude': lat,
            'longitude': lon,
            'timezone': geo_info.get('timezone', 'Unknown'),
            'isp': geo_info.get('org', 'Unknown')
        }
        
    except Exception as e:
        logger.error(f"Error with ipinfo.io: {str(e)}")
        raise Exception(f"Failed to get geolocation from ipinfo.io: {str(e)}")

# Test function for local development
if __name__ == "__main__":
    # Test event
    test_event = {
        'body': json.dumps({'ip': '8.8.8.8'}),
        'requestContext': {
            'identity': {
                'sourceIp': '192.168.1.1'
            }
        }
    }
    
    result = lambda_handler(test_event, None)
    print(json.dumps(result, indent=2))
    