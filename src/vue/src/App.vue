<template>
  <div class="container">
    <header>
      <h1>FungiVue</h1>
      <p class="subtitle">Ultrasound Mushroom Growth Imaging Dashboard</p>
    </header>

    <div class="status-bar">
      <div class="status-item">
        <span class="label">System:</span>
        <span :class="['value', systemStatus]">{{ systemStatus }}</span>
      </div>
      <div class="status-item">
        <span class="label">Last Scan:</span>
        <span class="value">{{ lastScanTime }}</span>
      </div>
      <div class="status-item">
        <span class="label">Scans:</span>
        <span class="value">{{ scans.length }}</span>
      </div>
    </div>

    <div class="controls">
      <button @click="refreshScans" class="btn btn-primary">Refresh Scans</button>
      <button @click="startImaging" class="btn btn-success" :disabled="imagingActive">
        {{ imagingActive ? 'Imaging Active' : 'Start Imaging' }}
      </button>
    </div>

    <section class="scans-section" v-if="scans.length > 0">
      <h2>Recent Scans</h2>
      <div class="scan-grid">
        <div v-for="(scan, index) in scans" :key="index" class="scan-card">
          <div class="scan-image">
            <img :src="scan.url" :alt="scan.name" @error="handleImageError" />
          </div>
          <div class="scan-info">
            <h3>{{ scan.name }}</h3>
            <p class="timestamp">{{ formatTimestamp(scan.timestamp) }}</p>
            <p class="details" v-if="scan.distance">{{ scan.distance }}mm</p>
          </div>
        </div>
      </div>
    </section>

    <section class="no-scans" v-else>
      <p>No scans available yet.</p>
      <p class="hint">Connect Arduino and start imaging to see results.</p>
    </section>

    <footer>
      <p>FungiVue v1.0.0 - Open Source Ultrasound Imaging</p>
    </footer>
  </div>
</template>

<script>
import axios from 'axios';

export default {
  name: 'App',
  data() {
    return {
      scans: [],
      systemStatus: 'initializing',
      lastScanTime: 'Never',
      imagingActive: false,
      apiEndpoint: '/api/scans',
      scanDir: '/scans/'
    };
  },
  mounted() {
    this.loadScans();
    this.checkSystemStatus();
    this.startStatusPolling();
  },
  beforeUnmount() {
    if (this.statusInterval) {
      clearInterval(this.statusInterval);
    }
  },
  methods: {
    async loadScans() {
      try {
        const response = await axios.get(this.apiEndpoint);
        if (Array.isArray(response.data)) {
          this.scans = response.data.map(scan => ({
            ...scan,
            url: scan.url.startsWith('/') ? scan.url : this.scanDir + scan.url
          }));
          if (this.scans.length > 0) {
            this.lastScanTime = this.scans[0].timestamp || 'Unknown';
            this.systemStatus = 'online';
          } else {
            this.systemStatus = 'no-scans';
          }
        }
      } catch (error) {
        console.warn('API unavailable, using fallback data');
        this.scans = this.getFallbackScans();
        this.systemStatus = 'offline';
      }
    },
    getFallbackScans() {
      return [
        { url: '/scans/sample.png', name: 'Sample Scan', timestamp: new Date().toISOString(), distance: '45mm' }
      ];
    },
    async refreshScans() {
      await this.loadScans();
    },
    async startImaging() {
      try {
        await axios.post('/api/start-imaging');
        this.imagingActive = true;
        setTimeout(() => {
          this.refreshScans();
        }, 5000);
      } catch (error) {
        console.error('Failed to start imaging:', error);
      }
    },
    checkSystemStatus() {
      if (this.scans.length > 0) {
        this.systemStatus = 'online';
      } else {
        this.systemStatus = 'waiting';
      }
    },
    startStatusPolling() {
      this.statusInterval = setInterval(() => {
        this.checkSystemStatus();
      }, 30000);
    },
    formatTimestamp(ts) {
      if (!ts) return 'Unknown';
      try {
        return new Date(ts).toLocaleString();
      } catch {
        return ts;
      }
    },
    handleImageError(e) {
      e.target.style.display = 'none';
    }
  }
};
</script>

<style>
.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
}

header {
  text-align: center;
  margin-bottom: 30px;
}

header h1 {
  font-size: 2.5rem;
  color: #2c3e50;
  margin-bottom: 5px;
}

.subtitle {
  color: #7f8c8d;
  font-size: 1.1rem;
}

.status-bar {
  display: flex;
  justify-content: center;
  gap: 30px;
  padding: 15px;
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  margin-bottom: 20px;
}

.status-item {
  display: flex;
  align-items: center;
  gap: 8px;
}

.label {
  font-weight: 600;
  color: #7f8c8d;
}

.value {
  color: #2c3e50;
}

.value.online { color: #27ae60; }
.value.waiting { color: #f39c12; }
.value.offline { color: #e74c3c; }
.value.no-scans { color: #95a5a6; }

.controls {
  display: flex;
  justify-content: center;
  gap: 15px;
  margin-bottom: 30px;
}

.btn {
  padding: 12px 24px;
  border: none;
  border-radius: 6px;
  font-size: 1rem;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-primary {
  background: #3498db;
  color: white;
}

.btn-primary:hover {
  background: #2980b9;
}

.btn-success {
  background: #27ae60;
  color: white;
}

.btn-success:hover {
  background: #229954;
}

.btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.scans-section h2 {
  margin-bottom: 20px;
  color: #2c3e50;
}

.scan-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 20px;
}

.scan-card {
  background: white;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  transition: transform 0.2s;
}

.scan-card:hover {
  transform: translateY(-4px);
}

.scan-image {
  height: 200px;
  background: #ecf0f1;
  display: flex;
  align-items: center;
  justify-content: center;
}

.scan-image img {
  max-width: 100%;
  max-height: 100%;
  object-fit: contain;
}

.scan-info {
  padding: 15px;
}

.scan-info h3 {
  margin-bottom: 8px;
  color: #2c3e50;
}

.timestamp {
  color: #7f8c8d;
  font-size: 0.9rem;
}

.details {
  margin-top: 8px;
  color: #3498db;
  font-weight: 600;
}

.no-scans {
  text-align: center;
  padding: 60px;
  background: white;
  border-radius: 8px;
}

.no-scans p {
  color: #7f8c8d;
  font-size: 1.2rem;
}

.hint {
  margin-top: 10px;
  font-size: 0.9rem !important;
}

footer {
  text-align: center;
  margin-top: 40px;
  padding: 20px;
  color: #7f8c8d;
}
</style>
