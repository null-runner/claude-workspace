#!/usr/bin/env python3
"""Main entry point for the application."""

import logging
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def main():
    """Main function."""
    logger.info("Starting application...")
    
    # Your code here
    print("Hello from Claude Project!")
    
    logger.info("Application finished.")


if __name__ == "__main__":
    main()