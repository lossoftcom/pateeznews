// Locale first — before any editor module evaluates its module-level strings.
import './setupLocale.js';
import { createRoot } from 'react-dom/client';
import Editor from './Editor.jsx';

createRoot(document.getElementById('root')).render(<Editor />);
