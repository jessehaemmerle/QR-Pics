import React, { useState, useEffect, createContext, useContext } from "react";
import "./App.css";
import { BrowserRouter, Routes, Route, Navigate, useNavigate, useParams } from "react-router-dom";
import axios from "axios";

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL;
const API = `${BACKEND_URL}/api`;

// Auth Context
const AuthContext = createContext();

const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (token) {
      axios.defaults.headers.common['Authorization'] = `Bearer ${token}`;
      checkAuth();
    } else {
      setLoading(false);
    }
  }, []);

  const checkAuth = async () => {
    try {
      const response = await axios.get(`${API}/auth/me`);
      setUser(response.data);
    } catch (error) {
      localStorage.removeItem('token');
      delete axios.defaults.headers.common['Authorization'];
    } finally {
      setLoading(false);
    }
  };

  const login = async (username, password) => {
    try {
      const response = await axios.post(`${API}/auth/login`, { username, password });
      const { access_token } = response.data;
      localStorage.setItem('token', access_token);
      axios.defaults.headers.common['Authorization'] = `Bearer ${access_token}`;
      await checkAuth();
      return true;
    } catch (error) {
      return false;
    }
  };

  const logout = () => {
    localStorage.removeItem('token');
    delete axios.defaults.headers.common['Authorization'];
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, login, logout, loading }}>
      {children}
    </AuthContext.Provider>
  );
};

const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

// Protected Route Component
const ProtectedRoute = ({ children }) => {
  const { user, loading } = useAuth();
  
  if (loading) {
    return <div className="min-h-screen flex items-center justify-center">
      <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-500"></div>
    </div>;
  }
  
  return user ? children : <Navigate to="/admin/login" />;
};

// Photo Gallery Component
const PhotoGallery = () => {
  const { sessionId } = useParams();
  const [session, setSession] = useState(null);
  const [photos, setPhotos] = useState([]);
  const [selectedPhotos, setSelectedPhotos] = useState([]);
  const [loading, setLoading] = useState(true);
  const [downloading, setDownloading] = useState(false);
  const navigate = useNavigate();

  useEffect(() => {
    fetchSessionAndPhotos();
  }, [sessionId]);

  const fetchSessionAndPhotos = async () => {
    try {
      const [sessionResponse, photosResponse] = await Promise.all([
        axios.get(`${API}/sessions/${sessionId}`),
        axios.get(`${API}/photos/session/${sessionId}`)
      ]);
      setSession(sessionResponse.data);
      setPhotos(photosResponse.data);
    } catch (error) {
      console.error('Error fetching session and photos:', error);
    } finally {
      setLoading(false);
    }
  };

  const downloadPhoto = (photo) => {
    const link = document.createElement('a');
    link.download = photo.filename;
    link.href = `data:${photo.content_type};base64,${photo.image_data}`;
    link.click();
  };

  const handleBulkDownload = async () => {
    if (selectedPhotos.length === 0) {
      alert('Please select photos to download');
      return;
    }

    setDownloading(true);
    try {
      const response = await axios.post(`${API}/photos/bulk-download`, selectedPhotos, {
        responseType: 'blob',
        headers: {
          'Content-Type': 'application/json',
        },
      });

      // Create download link
      const url = window.URL.createObjectURL(new Blob([response.data]));
      const link = document.createElement('a');
      link.href = url;
      
      // Get filename from response header or use default
      const contentDisposition = response.headers['content-disposition'];
      let filename = 'photos.zip';
      if (contentDisposition) {
        const filenameMatch = contentDisposition.match(/filename="(.+)"/);
        if (filenameMatch) {
          filename = filenameMatch[1];
        }
      }
      
      link.download = filename;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(url);

      // Clear selection after download
      setSelectedPhotos([]);
    } catch (error) {
      console.error('Error downloading photos:', error);
      alert('Error downloading photos. Please try again.');
    } finally {
      setDownloading(false);
    }
  };

  const handleSelectAll = () => {
    if (selectedPhotos.length === photos.length) {
      setSelectedPhotos([]);
    } else {
      setSelectedPhotos(photos.map(photo => photo.id));
    }
  };

  const handlePhotoSelect = (photoId) => {
    setSelectedPhotos(prev => 
      prev.includes(photoId) 
        ? prev.filter(id => id !== photoId)
        : [...prev, photoId]
    );
  };

  const deletePhoto = async (photoId) => {
    if (window.confirm('Are you sure you want to delete this photo?')) {
      try {
        await axios.delete(`${API}/photos/${photoId}`);
        setPhotos(photos.filter(photo => photo.id !== photoId));
        setSelectedPhotos(selectedPhotos.filter(id => id !== photoId));
      } catch (error) {
        console.error('Error deleting photo:', error);
      }
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-100 flex items-center justify-center">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-500"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-100">
      <div className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-6">
            <div>
              <button
                onClick={() => navigate('/admin')}
                className="text-blue-500 hover:text-blue-600 mb-2"
              >
                ← Back to Dashboard
              </button>
              <h1 className="text-3xl font-bold text-gray-900">
                {session?.name || 'Photo Gallery'}
              </h1>
              <p className="text-gray-600">
                {photos.length} photos uploaded
              </p>
            </div>
            
            {photos.length > 0 && (
              <div className="flex items-center space-x-4">
                <div className="text-sm text-gray-600">
                  {selectedPhotos.length} selected
                </div>
                <button
                  onClick={handleSelectAll}
                  className="bg-gray-500 hover:bg-gray-600 text-white px-4 py-2 rounded-md text-sm"
                >
                  {selectedPhotos.length === photos.length ? 'Deselect All' : 'Select All'}
                </button>
                <button
                  onClick={handleBulkDownload}
                  disabled={selectedPhotos.length === 0 || downloading}
                  className={`px-4 py-2 rounded-md text-sm font-medium ${
                    selectedPhotos.length === 0 || downloading
                      ? 'bg-gray-300 text-gray-500 cursor-not-allowed'
                      : 'bg-green-500 hover:bg-green-600 text-white'
                  }`}
                >
                  {downloading ? 'Downloading...' : `Download Selected (${selectedPhotos.length})`}
                </button>
              </div>
            )}
          </div>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {photos.length === 0 ? (
          <div className="text-center py-12">
            <p className="text-gray-500 text-lg">No photos uploaded yet</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
            {photos.map((photo) => (
              <div key={photo.id} className="bg-white rounded-lg shadow-lg overflow-hidden relative">
                {/* Selection checkbox */}
                <div className="absolute top-2 left-2 z-10">
                  <input
                    type="checkbox"
                    checked={selectedPhotos.includes(photo.id)}
                    onChange={() => handlePhotoSelect(photo.id)}
                    className="w-5 h-5 text-blue-600 bg-white border-gray-300 rounded focus:ring-blue-500"
                  />
                </div>
                
                <div className="aspect-w-16 aspect-h-12">
                  <img
                    src={`data:${photo.content_type};base64,${photo.image_data}`}
                    alt={photo.filename}
                    className="w-full h-48 object-cover"
                  />
                </div>
                <div className="p-4">
                  <h3 className="text-sm font-medium text-gray-900 truncate mb-2">
                    {photo.filename}
                  </h3>
                  <p className="text-xs text-gray-500 mb-2">
                    {new Date(photo.uploaded_at).toLocaleString()}
                  </p>
                  <p className="text-xs text-gray-500 mb-4">
                    {(photo.file_size / 1024 / 1024).toFixed(2)} MB
                  </p>
                  <div className="flex space-x-2">
                    <button
                      onClick={() => downloadPhoto(photo)}
                      className="flex-1 bg-blue-500 hover:bg-blue-600 text-white px-3 py-1 rounded text-sm"
                    >
                      Download
                    </button>
                    <button
                      onClick={() => deletePhoto(photo.id)}
                      className="flex-1 bg-red-500 hover:bg-red-600 text-white px-3 py-1 rounded text-sm"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

// User Management Component
const UserManagement = () => {
  const [users, setUsers] = useState([]);
  const [sessions, setSessions] = useState([]);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [editingUser, setEditingUser] = useState(null);
  const [newUser, setNewUser] = useState({
    username: '',
    password: '',
    is_superadmin: false,
    allowed_sessions: []
  });
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    fetchUsers();
    fetchSessions();
  }, []);

  const fetchUsers = async () => {
    try {
      const response = await axios.get(`${API}/users`);
      setUsers(response.data);
    } catch (error) {
      console.error('Error fetching users:', error);
    } finally {
      setLoading(false);
    }
  };

  const fetchSessions = async () => {
    try {
      const response = await axios.get(`${API}/sessions`);
      setSessions(response.data);
    } catch (error) {
      console.error('Error fetching sessions:', error);
    }
  };

  const createUser = async (e) => {
    e.preventDefault();
    try {
      await axios.post(`${API}/users`, newUser);
      setNewUser({
        username: '',
        password: '',
        is_superadmin: false,
        allowed_sessions: []
      });
      setShowCreateForm(false);
      fetchUsers();
    } catch (error) {
      console.error('Error creating user:', error);
      alert('Error creating user: ' + (error.response?.data?.detail || 'Unknown error'));
    }
  };

  const updateUser = async (e) => {
    e.preventDefault();
    try {
      await axios.put(`${API}/users/${editingUser.id}`, editingUser);
      setEditingUser(null);
      fetchUsers();
    } catch (error) {
      console.error('Error updating user:', error);
      alert('Error updating user: ' + (error.response?.data?.detail || 'Unknown error'));
    }
  };

  const deleteUser = async (userId) => {
    if (window.confirm('Are you sure you want to delete this user?')) {
      try {
        await axios.delete(`${API}/users/${userId}`);
        fetchUsers();
      } catch (error) {
        console.error('Error deleting user:', error);
        alert('Error deleting user: ' + (error.response?.data?.detail || 'Unknown error'));
      }
    }
  };

  const handleSessionToggle = (sessionId, isForNewUser = false) => {
    if (isForNewUser) {
      setNewUser(prev => ({
        ...prev,
        allowed_sessions: prev.allowed_sessions.includes(sessionId)
          ? prev.allowed_sessions.filter(id => id !== sessionId)
          : [...prev.allowed_sessions, sessionId]
      }));
    } else {
      setEditingUser(prev => ({
        ...prev,
        allowed_sessions: prev.allowed_sessions.includes(sessionId)
          ? prev.allowed_sessions.filter(id => id !== sessionId)
          : [...prev.allowed_sessions, sessionId]
      }));
    }
  };

  const getSessionName = (sessionId) => {
    const session = sessions.find(s => s.id === sessionId);
    return session ? session.name : 'Unknown Session';
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-100 flex items-center justify-center">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-500"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-100">
      <div className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-6">
            <div>
              <button
                onClick={() => navigate('/admin')}
                className="text-blue-500 hover:text-blue-600 mb-2"
              >
                ← Back to Dashboard
              </button>
              <h1 className="text-3xl font-bold text-gray-900">User Management</h1>
            </div>
            <button
              onClick={() => setShowCreateForm(!showCreateForm)}
              className="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded-md"
            >
              Add User
            </button>
          </div>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Create User Form */}
        {showCreateForm && (
          <div className="bg-white rounded-lg shadow p-6 mb-6">
            <h2 className="text-xl font-semibold mb-4">Create New User</h2>
            <form onSubmit={createUser} className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700">Username</label>
                  <input
                    type="text"
                    value={newUser.username}
                    onChange={(e) => setNewUser({...newUser, username: e.target.value})}
                    className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2"
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700">Password</label>
                  <input
                    type="password"
                    value={newUser.password}
                    onChange={(e) => setNewUser({...newUser, password: e.target.value})}
                    className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2"
                    required
                  />
                </div>
              </div>
              
              <div>
                <label className="flex items-center">
                  <input
                    type="checkbox"
                    checked={newUser.is_superadmin}
                    onChange={(e) => setNewUser({...newUser, is_superadmin: e.target.checked})}
                    className="mr-2"
                  />
                  <span className="text-sm font-medium text-gray-700">Superadmin</span>
                </label>
              </div>

              {!newUser.is_superadmin && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Session Access (Leave empty for all sessions)
                  </label>
                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-2">
                    {sessions.map((session) => (
                      <label key={session.id} className="flex items-center">
                        <input
                          type="checkbox"
                          checked={newUser.allowed_sessions.includes(session.id)}
                          onChange={() => handleSessionToggle(session.id, true)}
                          className="mr-2"
                        />
                        <span className="text-sm text-gray-700">{session.name}</span>
                      </label>
                    ))}
                  </div>
                </div>
              )}

              <div className="flex space-x-4">
                <button
                  type="submit"
                  className="bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded-md"
                >
                  Create User
                </button>
                <button
                  type="button"
                  onClick={() => setShowCreateForm(false)}
                  className="bg-gray-500 hover:bg-gray-600 text-white px-4 py-2 rounded-md"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        )}

        {/* Edit User Form */}
        {editingUser && (
          <div className="bg-white rounded-lg shadow p-6 mb-6">
            <h2 className="text-xl font-semibold mb-4">Edit User</h2>
            <form onSubmit={updateUser} className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700">Username</label>
                  <input
                    type="text"
                    value={editingUser.username}
                    onChange={(e) => setEditingUser({...editingUser, username: e.target.value})}
                    className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2"
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700">New Password (optional)</label>
                  <input
                    type="password"
                    value={editingUser.password || ''}
                    onChange={(e) => setEditingUser({...editingUser, password: e.target.value})}
                    className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2"
                  />
                </div>
              </div>
              
              <div>
                <label className="flex items-center">
                  <input
                    type="checkbox"
                    checked={editingUser.is_superadmin}
                    onChange={(e) => setEditingUser({...editingUser, is_superadmin: e.target.checked})}
                    className="mr-2"
                  />
                  <span className="text-sm font-medium text-gray-700">Superadmin</span>
                </label>
              </div>

              {!editingUser.is_superadmin && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Session Access (Leave empty for all sessions)
                  </label>
                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-2">
                    {sessions.map((session) => (
                      <label key={session.id} className="flex items-center">
                        <input
                          type="checkbox"
                          checked={editingUser.allowed_sessions.includes(session.id)}
                          onChange={() => handleSessionToggle(session.id, false)}
                          className="mr-2"
                        />
                        <span className="text-sm text-gray-700">{session.name}</span>
                      </label>
                    ))}
                  </div>
                </div>
              )}

              <div className="flex space-x-4">
                <button
                  type="submit"
                  className="bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded-md"
                >
                  Update User
                </button>
                <button
                  type="button"
                  onClick={() => setEditingUser(null)}
                  className="bg-gray-500 hover:bg-gray-600 text-white px-4 py-2 rounded-md"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        )}

        {/* Users List */}
        <div className="bg-white rounded-lg shadow">
          <div className="px-6 py-4 border-b border-gray-200">
            <h2 className="text-lg font-semibold text-gray-900">Users ({users.length})</h2>
          </div>
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Username
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Role
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Session Access
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Created
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {users.map((user) => (
                  <tr key={user.id}>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm font-medium text-gray-900">{user.username}</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                        user.is_superadmin 
                          ? 'bg-red-100 text-red-800' 
                          : 'bg-green-100 text-green-800'
                      }`}>
                        {user.is_superadmin ? 'Superadmin' : 'User'}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <div className="text-sm text-gray-900">
                        {user.is_superadmin ? (
                          <span className="text-blue-600">All Sessions</span>
                        ) : user.allowed_sessions.length === 0 ? (
                          <span className="text-blue-600">All Sessions</span>
                        ) : (
                          <div className="space-y-1">
                            {user.allowed_sessions.slice(0, 3).map(sessionId => (
                              <div key={sessionId} className="text-xs bg-gray-100 px-2 py-1 rounded">
                                {getSessionName(sessionId)}
                              </div>
                            ))}
                            {user.allowed_sessions.length > 3 && (
                              <div className="text-xs text-gray-500">
                                +{user.allowed_sessions.length - 3} more
                              </div>
                            )}
                          </div>
                        )}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {new Date(user.created_at).toLocaleDateString()}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                      <div className="flex space-x-2">
                        <button
                          onClick={() => setEditingUser(user)}
                          className="text-blue-600 hover:text-blue-900"
                        >
                          Edit
                        </button>
                        <button
                          onClick={() => deleteUser(user.id)}
                          className="text-red-600 hover:text-red-900"
                        >
                          Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
};

// Home Page Component
const Home = () => {
  const [sessions, setSessions] = useState([]);
  const [newSession, setNewSession] = useState({ name: '', description: '' });
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [qrCodes, setQrCodes] = useState({});
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    if (user) {
      fetchSessions();
    }
  }, [user]);

  const fetchSessions = async () => {
    try {
      const response = await axios.get(`${API}/sessions`);
      setSessions(response.data);
    } catch (error) {
      console.error('Error fetching sessions:', error);
    }
  };

  const createSession = async (e) => {
    e.preventDefault();
    try {
      await axios.post(`${API}/sessions`, newSession);
      setNewSession({ name: '', description: '' });
      setShowCreateForm(false);
      fetchSessions();
    } catch (error) {
      console.error('Error creating session:', error);
    }
  };

  const generateQR = async (sessionId) => {
    try {
      const response = await axios.get(`${API}/sessions/${sessionId}/qr`);
      setQrCodes(prev => ({
        ...prev,
        [sessionId]: response.data
      }));
    } catch (error) {
      console.error('Error generating QR code:', error);
    }
  };

  const downloadQR = (sessionId, sessionName) => {
    const qrData = qrCodes[sessionId];
    if (!qrData) return;
    
    const link = document.createElement('a');
    link.download = `${sessionName}_qr_code.png`;
    link.href = `data:image/png;base64,${qrData.qr_code}`;
    link.click();
  };

  if (!user) {
    return <Navigate to="/admin/login" />;
  }

  return (
    <div className="min-h-screen bg-gray-100">
      <div className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-6">
            <div className="flex items-center">
              <h1 className="text-3xl font-bold text-gray-900">QR Photo Upload</h1>
            </div>
            <div className="flex items-center space-x-4">
              <span className="text-sm text-gray-600">Welcome, {user.username}</span>
              {user.is_superadmin && (
                <button
                  onClick={() => navigate('/admin/users')}
                  className="bg-purple-500 hover:bg-purple-600 text-white px-4 py-2 rounded-md"
                >
                  Manage Users
                </button>
              )}
              <button
                onClick={() => setShowCreateForm(!showCreateForm)}
                className="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded-md"
              >
                New Session
              </button>
              <button
                onClick={() => logout()}
                className="bg-red-500 hover:bg-red-600 text-white px-4 py-2 rounded-md"
              >
                Logout
              </button>
            </div>
          </div>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {showCreateForm && (
          <div className="bg-white rounded-lg shadow p-6 mb-6">
            <h2 className="text-xl font-semibold mb-4">Create New Session</h2>
            <form onSubmit={createSession} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700">Session Name</label>
                <input
                  type="text"
                  value={newSession.name}
                  onChange={(e) => setNewSession({...newSession, name: e.target.value})}
                  className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Description</label>
                <textarea
                  value={newSession.description}
                  onChange={(e) => setNewSession({...newSession, description: e.target.value})}
                  className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2"
                  rows="3"
                />
              </div>
              <div className="flex space-x-4">
                <button
                  type="submit"
                  className="bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded-md"
                >
                  Create Session
                </button>
                <button
                  type="button"
                  onClick={() => setShowCreateForm(false)}
                  className="bg-gray-500 hover:bg-gray-600 text-white px-4 py-2 rounded-md"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        )}

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {sessions.map((session) => (
            <div key={session.id} className="bg-white rounded-lg shadow p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-2">{session.name}</h3>
              {session.description && (
                <p className="text-gray-600 mb-4">{session.description}</p>
              )}
              <p className="text-sm text-gray-500 mb-4">
                Created: {new Date(session.created_at).toLocaleString()}
              </p>
              
              <div className="space-y-3">
                <button
                  onClick={() => generateQR(session.id)}
                  className="w-full bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded-md"
                >
                  Generate QR Code
                </button>
                
                {qrCodes[session.id] && (
                  <div className="text-center">
                    <img
                      src={`data:image/png;base64,${qrCodes[session.id].qr_code}`}
                      alt="QR Code"
                      className="mx-auto mb-2"
                      style={{ width: '200px', height: '200px' }}
                    />
                    <button
                      onClick={() => downloadQR(session.id, session.name)}
                      className="bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded-md text-sm"
                    >
                      Download QR Code
                    </button>
                  </div>
                )}
                
                <div className="flex space-x-2">
                  <button
                    onClick={() => navigate(`/admin/photos/${session.id}`)}
                    className="flex-1 bg-purple-500 hover:bg-purple-600 text-white px-4 py-2 rounded-md text-sm"
                  >
                    View Photos
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

// Upload Page Component
const UploadPage = () => {
  const { sessionId } = useParams();
  const [session, setSession] = useState(null);
  const [files, setFiles] = useState([]);
  const [uploading, setUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState({});
  const [error, setError] = useState('');

  useEffect(() => {
    checkSession();
  }, [sessionId]);

  const checkSession = async () => {
    try {
      const response = await axios.get(`${API}/public/sessions/${sessionId}/check`);
      setSession(response.data);
    } catch (error) {
      setError('Session not found or inactive');
    }
  };

  const handleFileChange = (e) => {
    const selectedFiles = Array.from(e.target.files);
    setFiles(selectedFiles);
  };

  const uploadFile = async (file) => {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = async (e) => {
        try {
          const base64Data = e.target.result.split(',')[1];
          const photoData = {
            session_id: sessionId,
            filename: file.name,
            content_type: file.type,
            image_data: base64Data,
            file_size: file.size
          };
          
          await axios.post(`${API}/photos`, photoData);
          resolve();
        } catch (error) {
          reject(error);
        }
      };
      reader.onerror = reject;
      reader.readAsDataURL(file);
    });
  };

  const handleUpload = async () => {
    if (files.length === 0) return;
    
    setUploading(true);
    setError('');
    
    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      try {
        setUploadProgress(prev => ({ ...prev, [i]: 'uploading' }));
        await uploadFile(file);
        setUploadProgress(prev => ({ ...prev, [i]: 'completed' }));
      } catch (error) {
        setUploadProgress(prev => ({ ...prev, [i]: 'error' }));
        setError(`Failed to upload ${file.name}`);
      }
    }
    
    setUploading(false);
  };

  if (error) {
    return (
      <div className="min-h-screen bg-red-50 flex items-center justify-center">
        <div className="bg-white p-8 rounded-lg shadow-lg text-center">
          <h1 className="text-2xl font-bold text-red-600 mb-4">Error</h1>
          <p className="text-gray-700">{error}</p>
        </div>
      </div>
    );
  }

  if (!session) {
    return (
      <div className="min-h-screen bg-gray-100 flex items-center justify-center">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-500"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
      <div className="container mx-auto px-4 py-8">
        <div className="max-w-2xl mx-auto">
          <div className="bg-white rounded-lg shadow-lg p-8">
            <h1 className="text-3xl font-bold text-gray-900 mb-2 text-center">
              Upload Photos
            </h1>
            <p className="text-gray-600 text-center mb-6">
              Session: {session.session_name}
            </p>
            
            <div className="space-y-6">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Select Photos
                </label>
                <input
                  type="file"
                  multiple
                  accept="image/*"
                  onChange={handleFileChange}
                  className="block w-full text-sm text-gray-500
                    file:mr-4 file:py-2 file:px-4
                    file:rounded-full file:border-0
                    file:text-sm file:font-semibold
                    file:bg-blue-50 file:text-blue-700
                    hover:file:bg-blue-100"
                />
              </div>
              
              {files.length > 0 && (
                <div>
                  <h3 className="text-lg font-medium text-gray-900 mb-3">
                    Selected Files ({files.length})
                  </h3>
                  <div className="space-y-2">
                    {files.map((file, index) => (
                      <div key={index} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                        <span className="text-sm text-gray-700">{file.name}</span>
                        <div className="flex items-center space-x-2">
                          <span className="text-xs text-gray-500">
                            {(file.size / 1024 / 1024).toFixed(2)} MB
                          </span>
                          {uploadProgress[index] === 'uploading' && (
                            <div className="w-4 h-4 border-2 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
                          )}
                          {uploadProgress[index] === 'completed' && (
                            <div className="w-4 h-4 bg-green-500 rounded-full flex items-center justify-center">
                              <svg className="w-2 h-2 text-white" fill="currentColor" viewBox="0 0 20 20">
                                <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                              </svg>
                            </div>
                          )}
                          {uploadProgress[index] === 'error' && (
                            <div className="w-4 h-4 bg-red-500 rounded-full flex items-center justify-center">
                              <svg className="w-2 h-2 text-white" fill="currentColor" viewBox="0 0 20 20">
                                <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
                              </svg>
                            </div>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
              
              <button
                onClick={handleUpload}
                disabled={files.length === 0 || uploading}
                className={`w-full py-3 px-4 rounded-lg font-medium ${
                  files.length === 0 || uploading
                    ? 'bg-gray-300 text-gray-500 cursor-not-allowed'
                    : 'bg-blue-500 hover:bg-blue-600 text-white'
                }`}
              >
                {uploading ? 'Uploading...' : 'Upload Photos'}
              </button>
              
              {error && (
                <div className="p-4 bg-red-50 border border-red-200 rounded-lg">
                  <p className="text-red-600 text-sm">{error}</p>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

// Login Page Component
const LoginPage = () => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    
    const success = await login(username, password);
    if (success) {
      navigate('/admin');
    } else {
      setError('Invalid credentials');
    }
    setLoading(false);
  };

  return (
    <div className="min-h-screen bg-gray-100 flex items-center justify-center">
      <div className="bg-white p-8 rounded-lg shadow-lg w-full max-w-md">
        <h1 className="text-2xl font-bold text-gray-900 mb-6 text-center">
          Admin Login
        </h1>
        
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700">Username</label>
            <input
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2"
              required
            />
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700">Password</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2"
              required
            />
          </div>
          
          {error && (
            <div className="p-3 bg-red-50 border border-red-200 rounded-md">
              <p className="text-red-600 text-sm">{error}</p>
            </div>
          )}
          
          <button
            type="submit"
            disabled={loading}
            className={`w-full py-2 px-4 rounded-md font-medium ${
              loading
                ? 'bg-gray-300 text-gray-500 cursor-not-allowed'
                : 'bg-blue-500 hover:bg-blue-600 text-white'
            }`}
          >
            {loading ? 'Logging in...' : 'Login'}
          </button>
        </form>
        
        <div className="mt-4 text-center text-sm text-gray-600">
          <p>Default credentials: superadmin / changeme123</p>
        </div>
      </div>
    </div>
  );
};

// Main App Component
function App() {
  return (
    <div className="App">
      <BrowserRouter>
        <AuthProvider>
          <Routes>
            <Route path="/upload/:sessionId" element={<UploadPage />} />
            <Route path="/admin/login" element={<LoginPage />} />
            <Route path="/admin/users" element={
              <ProtectedRoute>
                <UserManagement />
              </ProtectedRoute>
            } />
            <Route path="/admin/photos/:sessionId" element={
              <ProtectedRoute>
                <PhotoGallery />
              </ProtectedRoute>
            } />
            <Route path="/admin" element={
              <ProtectedRoute>
                <Home />
              </ProtectedRoute>
            } />
            <Route path="/" element={<Navigate to="/admin" />} />
          </Routes>
        </AuthProvider>
      </BrowserRouter>
    </div>
  );
}

export default App;