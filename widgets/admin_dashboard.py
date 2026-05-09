from nicegui import ui

# Mock data for demonstration
users = [
    {'id': 1, 'name': 'Admin User', 'email': 'admin@example.com', 'role': 'Administrator', 'status': 'Active'},
    {'id': 2, 'name': 'John Doe', 'email': 'john@example.com', 'role': 'Editor', 'status': 'Active'},
    {'id': 3, 'name': 'Jane Smith', 'email': 'jane@example.com', 'role': 'Viewer', 'status': 'Inactive'},
]

# Authentication state (simplified for demo)
is_authenticated = False
current_user = None

# Login page
@ui.page('/')
def login_page():
    def try_login():
        nonlocal is_authenticated
        if username.value == 'admin' and password.value == 'password':
            is_authenticated = True
            ui.navigate('/dashboard')
        else:
            ui.notify('Invalid credentials', color='negative')
    
    with ui.card().classes('absolute-center w-96'):
        ui.label('Admin Dashboard Login').classes('text-h5 text-center')
        username = ui.input('Username').classes('w-full')
        password = ui.input('Password', password=True).classes('w-full')
        ui.button('Login', on_click=try_login).classes('w-full mt-4')

# Navigation component
def create_navigation():
    with ui.left_drawer().classes('bg-blue-100'):
        ui.label('Admin Panel').classes('text-h6 q-pa-md')
        ui.separator()
        with ui.column().classes('w-full'):
            ui.button('Dashboard', on_click=lambda: ui.navigate('/dashboard')).classes('w-full text-left')
            ui.button('Users', on_click=lambda: ui.navigate('/users')).classes('w-full text-left')
            ui.button('Settings', on_click=lambda: ui.navigate('/settings')).classes('w-full text-left')
            ui.separator()
            ui.button('Logout', on_click=lambda: logout()).classes('w-full text-left')

def logout():
    global is_authenticated
    is_authenticated = False
    ui.navigate('/')

# Dashboard page
@ui.page('/dashboard')
def dashboard():
    def check_auth():
        if not is_authenticated:
            ui.navigate('/')
    
    ui.timer(0.1, check_auth, once=True)
    
    with ui.header().classes('bg-blue-800 text-white'):
        ui.button(icon='menu', on_click=lambda: ui.left_drawer.toggle())
        ui.label('Admin Dashboard').classes('q-ml-sm')
    
    create_navigation()
    
    with ui.column().classes('q-pa-md w-full'):
        ui.label('Dashboard Overview').classes('text-h5')
        
        with ui.row().classes('w-full q-col-gutter-md'):
            with ui.card().classes('w-1/3'):
                ui.label('Total Users').classes('text-subtitle1')
                ui.label(f'{len(users)}').classes('text-h4')
            
            with ui.card().classes('w-1/3'):
                ui.label('Active Users').classes('text-subtitle1')
                active_count = sum(1 for user in users if user['status'] == 'Active')
                ui.label(f'{active_count}').classes('text-h4')
            
            with ui.card().classes('w-1/3'):
                ui.label('System Status').classes('text-subtitle1')
                ui.label('Online').classes('text-h4 text-positive')
        
        ui.label('Recent Activity').classes('text-h6 q-mt-lg')
        with ui.table().classes('w-full'):
            ui.table.column('Time', 'time')
            ui.table.column('User', 'user')
            ui.table.column('Action', 'action')
            ui.table.row({'time': '2025-05-15 14:30', 'user': 'Admin User', 'action': 'System Login'})
            ui.table.row({'time': '2025-05-15 14:25', 'user': 'John Doe', 'action': 'Updated Profile'})
            ui.table.row({'time': '2025-05-15 13:45', 'user': 'Jane Smith', 'action': 'Posted Comment'})

# Users page
@ui.page('/users')
def user_page():
    if not is_authenticated:
        ui.navigate('/')
    
    with ui.header().classes('bg-blue-800 text-white'):
        ui.button(icon='menu', on_click=lambda: ui.left_drawer.toggle())
        ui.label('User Management').classes('q-ml-sm')
    
    create_navigation()
    
    with ui.column().classes('q-pa-md w-full'):
        ui.label('User Management').classes('text-h5')
        
        # Add user form
        with ui.card().classes('q-mb-md w-full'):
            ui.label('Add New User').classes('text-h6')
            with ui.row().classes('w-full q-col-gutter-md'):
                name = ui.input('Name').classes('w-1/3')
                email = ui.input('Email').classes('w-1/3')
                role = ui.select('Role', options=['Administrator', 'Editor', 'Viewer']).classes('w-1/3')
            
            ui.button('Add User', on_click=lambda: ui.notify('User added (demo only)')).classes('q-mt-sm')
        
        # User table
        with ui.table().classes('w-full'):
            ui.table.column('ID', 'id')
            ui.table.column('Name', 'name')
            ui.table.column('Email', 'email')
            ui.table.column('Role', 'role')
            ui.table.column('Status', 'status')
            ui.table.column('Actions', 'actions')
            
            for user in users:
                row = {**user, 'actions': ''}
                ui.table.row(row)
                with ui.table.cell():
                    ui.button('Edit', icon='edit', color='primary', size='sm').classes('q-mr-xs')
                    ui.button('Delete', icon='delete', color='negative', size='sm')

# Settings page
@ui.page('/settings')
def settings_page():
    if not is_authenticated:
        ui.navigate('/')
    
    with ui.header().classes('bg-blue-800 text-white'):
        ui.button(icon='menu', on_click=lambda: ui.left_drawer.toggle())
        ui.label('System Settings').classes('q-ml-sm')
    
    create_navigation()
    
    with ui.column().classes('q-pa-md w-full'):
        ui.label('System Settings').classes('text-h5')
        
        with ui.tabs().classes('w-full') as tabs:
            ui.tab('General', icon='settings')
            ui.tab('Security', icon='security')
            ui.tab('Appearance', icon='palette')
        
        with ui.tab_panels(tabs, value='General').classes('w-full q-mt-md'):
            with ui.tab_panel('General'):
                ui.label('General Settings').classes('text-h6')
                ui.input('Site Name', value='Admin Portal')
                ui.input('Admin Email', value='admin@example.com')
                ui.checkbox('Enable Public Registration')
                ui.button('Save Changes', on_click=lambda: ui.notify('Settings saved')).classes('q-mt-md')
            
            with ui.tab_panel('Security'):
                ui.label('Security Settings').classes('text-h6')
                ui.input('Minimum Password Length', value='8', input_type='number')
                ui.checkbox('Require Password Reset Every 90 Days', value=True)
                ui.checkbox('Enable Two Factor Authentication', value=False)
                ui.button('Save Changes', on_click=lambda: ui.notify('Settings saved')).classes('q-mt-md')
            
            with ui.tab_panel('Appearance'):
                ui.label('Appearance Settings').classes('text-h6')
                ui.select('Theme', options=['Light', 'Dark', 'System'], value='Light')
                ui.select('Accent Color', options=['Blue', 'Green', 'Red', 'Purple'], value='Blue')
                ui.checkbox('Show Help Tips', value=True)
                ui.button('Save Changes', on_click=lambda: ui.notify('Settings saved')).classes('q-mt-md')

ui.run()