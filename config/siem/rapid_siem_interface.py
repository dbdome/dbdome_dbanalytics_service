import requests
import json
import logging
import time
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
import urllib3
from dataclasses import dataclass
import base64

# Disable SSL warnings if needed
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class SIEMEvent:
    """Data class for SIEM events"""
    timestamp: str
    source_ip: str
    destination_ip: str
    event_type: str
    severity: str
    message: str
    raw_log: str
    source_system: str = ""
    user: str = ""
    action: str = ""

@dataclass
class SIEMAlert:
    """Data class for SIEM alerts"""
    alert_id: str
    name: str
    severity: str
    status: str
    created_time: str
    description: str
    source_events: List[str]
    assigned_to: str = ""

class RapidSIEMClient:
    """
    Python client for interfacing with Rapid SIEM
    Supports REST API, Syslog, and database connections
    """
    
    def __init__(self, 
                 base_url: str,
                 username: str = None,
                 password: str = None,
                 api_key: str = None,
                 verify_ssl: bool = True,
                 timeout: int = 30):
        """
        Initialize Rapid SIEM client
        
        Args:
            base_url: Base URL of the SIEM system
            username: Username for authentication
            password: Password for authentication  
            api_key: API key for authentication
            verify_ssl: Whether to verify SSL certificates
            timeout: Request timeout in seconds
        """
        self.base_url = base_url.rstrip('/')
        self.username = username
        self.password = password
        self.api_key = api_key
        self.verify_ssl = verify_ssl
        self.timeout = timeout
        self.session = requests.Session()
        self.token = None
        
        # Set up authentication
        self._setup_authentication()
    
    def _setup_authentication(self):
        """Setup authentication headers"""
        if self.api_key:
            self.session.headers.update({
                'Authorization': f'Bearer {self.api_key}',
                'Content-Type': 'application/json'
            })
        elif self.username and self.password:
            # Basic Auth
            credentials = base64.b64encode(f"{self.username}:{self.password}".encode()).decode()
            self.session.headers.update({
                'Authorization': f'Basic {credentials}',
                'Content-Type': 'application/json'
            })
    
    def authenticate(self) -> bool:
        """
        Authenticate with the SIEM system and get access token
        
        Returns:
            bool: True if authentication successful
        """
        try:
            auth_endpoint = f"{self.base_url}/api/auth/login"
            payload = {
                "username": self.username,
                "password": self.password
            }
            
            response = self.session.post(
                auth_endpoint,
                json=payload,
                verify=self.verify_ssl,
                timeout=self.timeout
            )
            
            if response.status_code == 200:
                auth_data = response.json()
                self.token = auth_data.get('access_token') or auth_data.get('token')
                
                if self.token:
                    self.session.headers.update({
                        'Authorization': f'Bearer {self.token}'
                    })
                    logger.info("Authentication successful")
                    return True
            
            logger.error(f"Authentication failed: {response.status_code} - {response.text}")
            return False
            
        except Exception as e:
            logger.error(f"Authentication error: {str(e)}")
            return False
    
    def get_events(self, 
                   start_time: datetime = None,
                   end_time: datetime = None,
                   source_ip: str = None,
                   event_type: str = None,
                   severity: str = None,
                   limit: int = 100) -> List[SIEMEvent]:
        """
        Retrieve security events from SIEM
        
        Args:
            start_time: Start time for event search
            end_time: End time for event search
            source_ip: Filter by source IP
            event_type: Filter by event type
            severity: Filter by severity level
            limit: Maximum number of events to return
            
        Returns:
            List of SIEMEvent objects
        """
        try:
            endpoint = f"{self.base_url}/api/events"
            
            # Build query parameters
            params = {
                'limit': limit
            }
            
            if start_time:
                params['start_time'] = start_time.isoformat()
            if end_time:
                params['end_time'] = end_time.isoformat()
            if source_ip:
                params['source_ip'] = source_ip
            if event_type:
                params['event_type'] = event_type
            if severity:
                params['severity'] = severity
            
            response = self.session.get(
                endpoint,
                params=params,
                verify=self.verify_ssl,
                timeout=self.timeout
            )
            
            if response.status_code == 200:
                events_data = response.json()
                events = []
                
                for event_dict in events_data.get('events', []):
                    event = SIEMEvent(
                        timestamp=event_dict.get('timestamp', ''),
                        source_ip=event_dict.get('source_ip', ''),
                        destination_ip=event_dict.get('destination_ip', ''),
                        event_type=event_dict.get('event_type', ''),
                        severity=event_dict.get('severity', ''),
                        message=event_dict.get('message', ''),
                        raw_log=event_dict.get('raw_log', ''),
                        source_system=event_dict.get('source_system', ''),
                        user=event_dict.get('user', ''),
                        action=event_dict.get('action', '')
                    )
                    events.append(event)
                
                logger.info(f"Retrieved {len(events)} events")
                return events
            else:
                logger.error(f"Failed to get events: {response.status_code} - {response.text}")
                return []
                
        except Exception as e:
            logger.error(f"Error retrieving events: {str(e)}")
            return []
    
    def get_alerts(self, 
                   status: str = None,
                   severity: str = None,
                   start_time: datetime = None,
                   end_time: datetime = None,
                   limit: int = 50) -> List[SIEMAlert]:
        """
        Retrieve security alerts from SIEM
        
        Args:
            status: Filter by alert status (open, closed, investigating)
            severity: Filter by severity (critical, high, medium, low)
            start_time: Start time for alert search
            end_time: End time for alert search
            limit: Maximum number of alerts to return
            
        Returns:
            List of SIEMAlert objects
        """
        try:
            endpoint = f"{self.base_url}/api/alerts"
            
            params = {'limit': limit}
            if status:
                params['status'] = status
            if severity:
                params['severity'] = severity
            if start_time:
                params['start_time'] = start_time.isoformat()
            if end_time:
                params['end_time'] = end_time.isoformat()
            
            response = self.session.get(
                endpoint,
                params=params,
                verify=self.verify_ssl,
                timeout=self.timeout
            )
            
            if response.status_code == 200:
                alerts_data = response.json()
                alerts = []
                
                for alert_dict in alerts_data.get('alerts', []):
                    alert = SIEMAlert(
                        alert_id=alert_dict.get('id', ''),
                        name=alert_dict.get('name', ''),
                        severity=alert_dict.get('severity', ''),
                        status=alert_dict.get('status', ''),
                        created_time=alert_dict.get('created_time', ''),
                        description=alert_dict.get('description', ''),
                        source_events=alert_dict.get('source_events', []),
                        assigned_to=alert_dict.get('assigned_to', '')
                    )
                    alerts.append(alert)
                
                logger.info(f"Retrieved {len(alerts)} alerts")
                return alerts
            else:
                logger.error(f"Failed to get alerts: {response.status_code} - {response.text}")
                return []
                
        except Exception as e:
            logger.error(f"Error retrieving alerts: {str(e)}")
            return []
    
    def create_alert(self, 
                     name: str,
                     severity: str,
                     description: str,
                     source_events: List[str] = None) -> Optional[str]:
        """
        Create a new security alert
        
        Args:
            name: Alert name
            severity: Alert severity (critical, high, medium, low)
            description: Alert description
            source_events: List of source event IDs
            
        Returns:
            Alert ID if successful, None otherwise
        """
        try:
            endpoint = f"{self.base_url}/api/alerts"
            
            payload = {
                'name': name,
                'severity': severity,
                'description': description,
                'source_events': source_events or [],
                'status': 'open',
                'created_time': datetime.now().isoformat()
            }
            
            response = self.session.post(
                endpoint,
                json=payload,
                verify=self.verify_ssl,
                timeout=self.timeout
            )
            
            if response.status_code in [200, 201]:
                result = response.json()
                alert_id = result.get('id') or result.get('alert_id')
                logger.info(f"Created alert: {alert_id}")
                return alert_id
            else:
                logger.error(f"Failed to create alert: {response.status_code} - {response.text}")
                return None
                
        except Exception as e:
            logger.error(f"Error creating alert: {str(e)}")
            return None
    
    def update_alert_status(self, alert_id: str, status: str, assigned_to: str = None) -> bool:
        """
        Update alert status
        
        Args:
            alert_id: Alert ID to update
            status: New status (open, investigating, closed)
            assigned_to: User to assign the alert to
            
        Returns:
            True if successful
        """
        try:
            endpoint = f"{self.base_url}/api/alerts/{alert_id}"
            
            payload = {
                'status': status,
                'updated_time': datetime.now().isoformat()
            }
            
            if assigned_to:
                payload['assigned_to'] = assigned_to
            
            response = self.session.patch(
                endpoint,
                json=payload,
                verify=self.verify_ssl,
                timeout=self.timeout
            )
            
            if response.status_code == 200:
                logger.info(f"Updated alert {alert_id} status to {status}")
                return True
            else:
                logger.error(f"Failed to update alert: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            logger.error(f"Error updating alert: {str(e)}")
            return False
    
    def send_event(self, event: SIEMEvent) -> bool:
        """
        Send a security event to SIEM
        
        Args:
            event: SIEMEvent object to send
            
        Returns:
            True if successful
        """
        try:
            endpoint = f"{self.base_url}/api/events"
            
            payload = {
                'timestamp': event.timestamp,
                'source_ip': event.source_ip,
                'destination_ip': event.destination_ip,
                'event_type': event.event_type,
                'severity': event.severity,
                'message': event.message,
                'raw_log': event.raw_log,
                'source_system': event.source_system,
                'user': event.user,
                'action': event.action
            }
            
            response = self.session.post(
                endpoint,
                json=payload,
                verify=self.verify_ssl,
                timeout=self.timeout
            )
            
            if response.status_code in [200, 201]:
                logger.info(f"Event sent successfully")
                return True
            else:
                logger.error(f"Failed to send event: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            logger.error(f"Error sending event: {str(e)}")
            return False
    
    def search_events(self, query: str, limit: int = 100) -> List[SIEMEvent]:
        """
        Search events using a query string
        
        Args:
            query: Search query (syntax depends on SIEM)
            limit: Maximum number of results
            
        Returns:
            List of matching events
        """
        try:
            endpoint = f"{self.base_url}/api/search/events"
            
            payload = {
                'query': query,
                'limit': limit
            }
            
            response = self.session.post(
                endpoint,
                json=payload,
                verify=self.verify_ssl,
                timeout=self.timeout
            )
            
            if response.status_code == 200:
                results = response.json()
                events = []
                
                for event_dict in results.get('events', []):
                    event = SIEMEvent(
                        timestamp=event_dict.get('timestamp', ''),
                        source_ip=event_dict.get('source_ip', ''),
                        destination_ip=event_dict.get('destination_ip', ''),
                        event_type=event_dict.get('event_type', ''),
                        severity=event_dict.get('severity', ''),
                        message=event_dict.get('message', ''),
                        raw_log=event_dict.get('raw_log', ''),
                        source_system=event_dict.get('source_system', ''),
                        user=event_dict.get('user', ''),
                        action=event_dict.get('action', '')
                    )
                    events.append(event)
                
                logger.info(f"Search returned {len(events)} events")
                return events
            else:
                logger.error(f"Search failed: {response.status_code} - {response.text}")
                return []
                
        except Exception as e:
            logger.error(f"Search error: {str(e)}")
            return []
    
    def get_system_health(self) -> Dict[str, Any]:
        """
        Get SIEM system health status
        
        Returns:
            Dictionary with health information
        """
        try:
            endpoint = f"{self.base_url}/api/health"
            
            response = self.session.get(
                endpoint,
                verify=self.verify_ssl,
                timeout=self.timeout
            )
            
            if response.status_code == 200:
                health_data = response.json()
                logger.info("Retrieved system health data")
                return health_data
            else:
                logger.error(f"Failed to get health data: {response.status_code}")
                return {}
                
        except Exception as e:
            logger.error(f"Health check error: {str(e)}")
            return {}


class SIEMDashboard:
    """Dashboard integration for SIEM data"""
    
    def __init__(self, siem_client: RapidSIEMClient):
        self.siem = siem_client
    
    def get_dashboard_stats(self) -> Dict[str, Any]:
        """Get statistics for dashboard display"""
        try:
            # Get recent alerts
            recent_alerts = self.siem.get_alerts(limit=100)
            
            # Get recent events  
            end_time = datetime.now()
            start_time = end_time - timedelta(hours=24)
            recent_events = self.siem.get_events(start_time=start_time, end_time=end_time)
            
            # Calculate statistics
            stats = {
                'total_alerts': len(recent_alerts),
                'critical_alerts': len([a for a in recent_alerts if a.severity == 'critical']),
                'open_alerts': len([a for a in recent_alerts if a.status == 'open']),
                'total_events_24h': len(recent_events),
                'critical_events_24h': len([e for e in recent_events if e.severity == 'critical']),
                'unique_source_ips': len(set([e.source_ip for e in recent_events if e.source_ip])),
                'event_types': {},
                'alerts_by_severity': {},
                'system_health': self.siem.get_system_health()
            }
            
            # Count event types
            for event in recent_events:
                event_type = event.event_type
                stats['event_types'][event_type] = stats['event_types'].get(event_type, 0) + 1
            
            # Count alerts by severity
            for alert in recent_alerts:
                severity = alert.severity
                stats['alerts_by_severity'][severity] = stats['alerts_by_severity'].get(severity, 0) + 1
            
            return stats
            
        except Exception as e:
            logger.error(f"Error getting dashboard stats: {str(e)}")
            return {}
    
    def get_threat_timeline(self, hours: int = 24) -> List[Dict[str, Any]]:
        """Get threat timeline data for charts"""
        try:
            end_time = datetime.now()
            start_time = end_time - timedelta(hours=hours)
            
            events = self.siem.get_events(start_time=start_time, end_time=end_time, limit=1000)
            
            # Group events by hour
            timeline = {}
            for event in events:
                try:
                    event_time = datetime.fromisoformat(event.timestamp.replace('Z', '+00:00'))
                    hour_key = event_time.strftime('%Y-%m-%d %H:00')
                    
                    if hour_key not in timeline:
                        timeline[hour_key] = {'threats_detected': 0, 'threats_blocked': 0}
                    
                    timeline[hour_key]['threats_detected'] += 1
                    
                    # Assume events with action 'blocked' are blocked threats
                    if event.action == 'blocked':
                        timeline[hour_key]['threats_blocked'] += 1
                        
                except Exception:
                    continue
            
            # Convert to list format for charts
            result = []
            for hour, counts in sorted(timeline.items()):
                result.append({
                    'time': hour,
                    'threats_detected': counts['threats_detected'],
                    'threats_blocked': counts['threats_blocked']
                })
            
            return result
            
        except Exception as e:
            logger.error(f"Error getting threat timeline: {str(e)}")
            return []


# Example usage and testing
def main():
    """Example usage of the Rapid SIEM interface"""
    
    # Initialize SIEM client
    siem = RapidSIEMClient(
        base_url="https://your-siem-server.com",
        username="admin",
        password="your_password",
        verify_ssl=False  # Set to True in production
    )
    
    # Authenticate
    if not siem.authenticate():
        print("Authentication failed")
        return
    
    # Get recent alerts
    print("\n=== Recent Alerts ===")
    alerts = siem.get_alerts(limit=10)
    for alert in alerts:
        print(f"Alert: {alert.name} | Severity: {alert.severity} | Status: {alert.status}")
    
    # Get recent events
    print("\n=== Recent Events ===")
    end_time = datetime.now()
    start_time = end_time - timedelta(hours=1)
    events = siem.get_events(start_time=start_time, end_time=end_time, limit=10)
    for event in events:
        print(f"Event: {event.event_type} | Source: {event.source_ip} | Severity: {event.severity}")
    
    # Create a test alert
    print("\n=== Creating Test Alert ===")
    alert_id = siem.create_alert(
        name="Test SQL Injection Alert",
        severity="high",
        description="Detected potential SQL injection attack from automated monitoring"
    )
    
    if alert_id:
        print(f"Created alert with ID: {alert_id}")
        
        # Update alert status
        success = siem.update_alert_status(alert_id, "investigating", "security_analyst")
        if success:
            print("Alert status updated successfully")
    
    # Get dashboard statistics
    print("\n=== Dashboard Statistics ===")
    dashboard = SIEMDashboard(siem)
    stats = dashboard.get_dashboard_stats()
    print(f"Total alerts: {stats.get('total_alerts', 0)}")
    print(f"Critical alerts: {stats.get('critical_alerts', 0)}")
    print(f"Events in last 24h: {stats.get('total_events_24h', 0)}")
    
    # Get threat timeline
    timeline = dashboard.get_threat_timeline(hours=6)
    print(f"\nThreat timeline entries: {len(timeline)}")
    
    # Search for specific events
    print("\n=== Search Results ===")
    search_results = siem.search_events("event_type:login AND severity:high", limit=5)
    print(f"Found {len(search_results)} matching events")


if __name__ == "__main__":
    main()
