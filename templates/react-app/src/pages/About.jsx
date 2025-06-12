import './About.css'

const About = () => {
  return (
    <div className="about">
      <div className="about-hero">
        <h1>About This Project</h1>
        <p className="about-subtitle">
          A modern React application built with Claude AI assistance
        </p>
      </div>
      
      <div className="about-content">
        <section className="about-section">
          <h2>🚀 Technology Stack</h2>
          <div className="tech-grid">
            <div className="tech-item">
              <h3>React 18</h3>
              <p>Modern React with hooks and concurrent features</p>
            </div>
            <div className="tech-item">
              <h3>Vite</h3>
              <p>Lightning fast build tool and development server</p>
            </div>
            <div className="tech-item">
              <h3>React Router</h3>
              <p>Declarative routing for React applications</p>
            </div>
            <div className="tech-item">
              <h3>Modern CSS</h3>
              <p>CSS modules with responsive design</p>
            </div>
          </div>
        </section>
        
        <section className="about-section">
          <h2>✨ Features</h2>
          <ul className="features-list">
            <li>Fast development with Hot Module Replacement</li>
            <li>Component-based architecture</li>
            <li>Responsive design</li>
            <li>Modern JavaScript (ES6+)</li>
            <li>CSS-in-JS styling</li>
            <li>Built-in routing</li>
          </ul>
        </section>
        
        <section className="about-section">
          <h2>🛠️ Development</h2>
          <div className="dev-info">
            <p>This project was created using the Claude React template, which provides:</p>
            <ul>
              <li>Pre-configured development environment</li>
              <li>Example components and pages</li>
              <li>Best practices and modern patterns</li>
              <li>Ready-to-use styling system</li>
            </ul>
          </div>
        </section>
        
        <section className="about-section">
          <h2>📚 Getting Started</h2>
          <div className="getting-started">
            <pre><code>{`# Install dependencies
npm install

# Start development server
npm run dev

# Build for production
npm run build`}</code></pre>
          </div>
        </section>
      </div>
    </div>
  )
}

export default About