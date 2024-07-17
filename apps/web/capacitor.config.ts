import type { CapacitorConfig } from '@capacitor/cli';

let config: CapacitorConfig = {
  appId: 'app.nutsack.club',
  appName: 'Nutsack',
  webDir: 'build',
  bundledWebRuntime: false
};

if (process.env.NODE_ENV === 'development') {
  config = {
    bundledWebRuntime: false,
    server: {
      // url: "http://192.168.1.115:3000",
      // url: "http://10.10.242.180:3001",
      // url: "http://10.8.4.16:3000",
      // url: "http://10.8.4.108:3000",
      cleartext: true
    },
    ...config
  }
}

export default config;
