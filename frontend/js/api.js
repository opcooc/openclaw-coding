// 华规绩效系统 - API 封装
// 位置：frontend/js/api.js

const API_BASE_URL = 'http://192.168.3.79:8081/api';

// 工具函数
const api = {
  getToken() {
    return localStorage.getItem('auth_token');
  },
  setToken(token) {
    localStorage.setItem('auth_token', token);
  },
  removeToken() {
    localStorage.removeItem('auth_token');
    localStorage.removeItem('current_user');
  },
  getCurrentUser() {
    const user = localStorage.getItem('current_user');
    return user ? JSON.parse(user) : null;
  },
  setCurrentUser(user) {
    localStorage.setItem('current_user', JSON.stringify(user));
  },
  async request(url, options = {}) {
    const token = this.getToken();
    const headers = { 'Content-Type': 'application/json', ...options.headers };
    if (token) headers['Authorization'] = `Bearer ${token}`;
    try {
      const response = await fetch(`${API_BASE_URL}${url}`, { ...options, headers });
      const data = await response.json();
      if (!response.ok) throw new Error(data.message || '请求失败');
      return data;
    } catch (error) {
      console.error('API 请求错误:', error);
      throw error;
    }
  },
  async get(url) { return this.request(url, { method: 'GET' }); },
  async post(url, data) { return this.request(url, { method: 'POST', body: JSON.stringify(data) }); },
  async put(url, data) { return this.request(url, { method: 'PUT', body: JSON.stringify(data) }); },
  async delete(url) { return this.request(url, { method: 'DELETE' }); }
};

// 认证模块
const authAPI = {
  async login(username, password) {
    const response = await api.post('/auth/login', { username, password });
    // 后端返回 { code: 200, data: { token, refreshToken, username, realName } }
    if (response.code === 200 && response.data) {
      const d = response.data;
      api.setToken(d.token);
      api.setCurrentUser({
        id: d.id || null,
        name: d.realName || d.username,
        username: d.username,
        role: d.role || 'employee',
        deptId: d.deptId || null,
        deptName: d.deptName || ''
      });
    }
    return response;
  },
  async logout() {
    try { await api.post('/auth/logout'); } catch(e) { /* 忽略登出错误 */ }
    api.removeToken();
    return { success: true };
  },
  async refreshToken() {
    const response = await api.post('/auth/refresh');
    if (response.code === 200 && response.data) api.setToken(response.data);
    return response;
  }
};

// 用户管理
const userAPI = {
  async getList(params = {}) {
    const query = new URLSearchParams(params).toString();
    return api.get(`/users?${query}`);
  },
  async getById(id) { return api.get(`/users/${id}`); },
  async create(data) { return api.post('/users', data); },
  async update(id, data) { return api.put(`/users/${id}`, data); },
  async delete(id) { return api.delete(`/users/${id}`); }
};

// 目标管理
const goalAPI = {
  async getList(params = {}) {
    const query = new URLSearchParams(params).toString();
    return api.get(`/goals?${query}`);
  },
  async create(data) { return api.post('/goals', data); },
  async submit(id) { return api.put(`/goals/${id}/submit`); },
  async approve(id) { return api.put(`/goals/${id}/approve`); },
  async reject(id, reason) { return api.put(`/goals/${id}/reject`, { reason }); }
};

// 任务管理
const taskAPI = {
  async getList(params = {}) {
    const query = new URLSearchParams(params).toString();
    return api.get(`/tasks?${query}`);
  },
  async create(data) { return api.post('/tasks', data); },
  async update(id, data) { return api.put(`/tasks/${id}`, data); },
  async delete(id) { return api.delete(`/tasks/${id}`); },
  async submit(id) { return api.put(`/tasks/${id}/submit`); },
  async approve(id) { return api.put(`/tasks/${id}/approve`); },
  async reject(id, reason) { return api.put(`/tasks/${id}/reject`, { reason }); }
};

// 考核周期
const cycleAPI = {
  async getList(params = {}) {
    const query = new URLSearchParams(params).toString();
    return api.get(`/cycles?${query}`);
  },
  async getById(id) { return api.get(`/cycles/${id}`); }
};

// 考核打分模板（权重/考核项）
const templateAPI = {
  async getByCycle(cycleId) {
    return api.get(`/templates?cycleId=${cycleId}`);
  },
  async getBusinessData(params = {}) {
    const query = new URLSearchParams(params).toString();
    return api.get(`/templates/business-data?${query}`);
  }
};

// 配置管理（统一入口）
const configAPI = {
  async getCycles() { return api.get('/config/cycles'); },
  async getRatingTemplate() { return api.get('/config/rating-template'); }
};

// 部门管理
const deptAPI = {
  async getList() { return api.get('/depts'); },
  async getTree() { return api.get('/depts/tree'); }
};

// 考核打分
const scoreAPI = {
  async getList(params = {}) {
    const query = new URLSearchParams(params).toString();
    return api.get(`/scores?${query}`);
  },
  async create(data) { return api.post('/scores', data); },
  async getMyScores(cycleId) { return api.get(`/scores/my?cycleId=${cycleId}`); },
  async delete(id) { return api.delete(`/scores/${id}`); }
};

// 工资管理
const salaryAPI = {
  async getList(params = {}) {
    const query = new URLSearchParams(params).toString();
    return api.get(`/salaries?${query}`);
  },
  async create(data) { return api.post('/salaries', data); }
};

// 导出全局对象
window.api = api;
window.authAPI = authAPI;
window.userAPI = userAPI;
window.goalAPI = goalAPI;
window.taskAPI = taskAPI;
window.scoreAPI = scoreAPI;
window.salaryAPI = salaryAPI;
window.cycleAPI = cycleAPI;
window.templateAPI = templateAPI;
window.configAPI = configAPI;
window.deptAPI = deptAPI;
