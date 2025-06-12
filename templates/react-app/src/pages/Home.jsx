import { useState } from 'react'
import Counter from '../components/Counter'
import './Home.css'

const Home = () => {
  const [message, setMessage] = useState('Welcome to your Claude React App!')

  return (
    <div className="home">
      <header className="home-header">
        <h1>🚀 Claude React Template</h1>
        <p className="home-message">{message}</p>
      </header>
      
      <section className="home-content">
        <div className="feature-grid">
          <div className="feature-card">
            <h3>⚡ Vite Powered</h3>
            <p>Lightning fast development with Hot Module Replacement</p>
          </div>
          
          <div className="feature-card">
            <h3>🧩 Component Based</h3>
            <p>Modular architecture with reusable components</p>
          </div>
          
          <div className="feature-card">
            <h3>🛣️ React Router</h3>
            <p>Client-side routing for single page applications</p>
          </div>
          
          <div className="feature-card">
            <h3>🎨 Modern CSS</h3>
            <p>CSS modules and modern styling techniques</p>
          </div>
        </div>
        
        <div className="demo-section">
          <h2>Interactive Demo</h2>
          <Counter />
          
          <div className="message-changer">
            <label htmlFor="message-input">Change welcome message:</label>
            <input
              id="message-input"
              type="text"
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              placeholder="Enter your message..."
            />
          </div>
        </div>
      </section>
    </div>
  )
}

export default Home