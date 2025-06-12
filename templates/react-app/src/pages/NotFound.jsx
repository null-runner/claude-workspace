import { Link } from 'react-router-dom'
import './NotFound.css'

const NotFound = () => {
  return (
    <div className="not-found">
      <div className="not-found-content">
        <h1 className="error-code">404</h1>
        <h2 className="error-title">Page Not Found</h2>
        <p className="error-description">
          The page you're looking for doesn't exist or has been moved.
        </p>
        <div className="error-actions">
          <Link to="/" className="btn btn-primary">
            Go Home
          </Link>
          <button onClick={() => window.history.back()} className="btn btn-outline">
            Go Back
          </button>
        </div>
      </div>
    </div>
  )
}

export default NotFound