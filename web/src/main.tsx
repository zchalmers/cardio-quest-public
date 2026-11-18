import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import App from '@/App';
import { CardioDataProvider } from '@/data/CardioDataProvider';
import '@/index.css';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <CardioDataProvider>
      <BrowserRouter>
        <App />
      </BrowserRouter>
    </CardioDataProvider>
  </React.StrictMode>,
);
