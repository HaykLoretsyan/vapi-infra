#!/bin/bash

# Script to access MongoDB in Docker container
# Usage: ./access-mongo.sh [command]
#   - No arguments: Opens mongosh shell
#   - "list": Lists all databases
#   - "collections": Lists all collections in vapi database
#   - "show <collection>": Shows documents in a collection

CONTAINER_NAME="vapi-mongo"
MONGO_USERNAME=${MONGO_USERNAME:-admin}
MONGO_PASSWORD=${MONGO_PASSWORD:-admin}
MONGO_DATABASE=${MONGO_DATABASE:-vapi}

# Check if running in interactive mode
if [ -t 0 ] && [ -t 1 ]; then
    DOCKER_EXEC="docker exec -it"
else
    DOCKER_EXEC="docker exec"
fi

case "$1" in
    "list")
        echo "📋 Listing all databases..."
        $DOCKER_EXEC $CONTAINER_NAME mongosh -u $MONGO_USERNAME -p $MONGO_PASSWORD --authenticationDatabase admin --quiet --eval "db.adminCommand('listDatabases')"
        ;;
    "collections")
        echo "📋 Listing collections in '$MONGO_DATABASE' database..."
        $DOCKER_EXEC $CONTAINER_NAME mongosh -u $MONGO_USERNAME -p $MONGO_PASSWORD --authenticationDatabase admin $MONGO_DATABASE --quiet --eval "db.getCollectionNames()"
        ;;
    "show")
        if [ -z "$2" ]; then
            echo "❌ Please specify a collection name"
            echo "Usage: $0 show <collection_name>"
            exit 1
        fi
        echo "📋 Showing documents in '$2' collection..."
        $DOCKER_EXEC $CONTAINER_NAME mongosh -u $MONGO_USERNAME -p $MONGO_PASSWORD --authenticationDatabase admin $MONGO_DATABASE --quiet --eval "db.$2.find().pretty()"
        ;;
    "count")
        if [ -z "$2" ]; then
            echo "❌ Please specify a collection name"
            echo "Usage: $0 count <collection_name>"
            exit 1
        fi
        echo "📊 Counting documents in '$2' collection..."
        $DOCKER_EXEC $CONTAINER_NAME mongosh -u $MONGO_USERNAME -p $MONGO_PASSWORD --authenticationDatabase admin $MONGO_DATABASE --quiet --eval "db.$2.countDocuments()"
        ;;
    "stats")
        echo "📊 Database statistics..."
        $DOCKER_EXEC $CONTAINER_NAME mongosh -u $MONGO_USERNAME -p $MONGO_PASSWORD --authenticationDatabase admin $MONGO_DATABASE --quiet --eval "db.stats()"
        ;;
    *)
        if [ -t 0 ] && [ -t 1 ]; then
            echo "🔌 Opening MongoDB shell..."
            echo "   Database: $MONGO_DATABASE"
            echo "   Use 'show dbs' to list databases"
            echo "   Use 'use $MONGO_DATABASE' to switch to vapi database"
            echo "   Use 'show collections' to list collections"
            echo "   Use 'db.<collection>.find().pretty()' to view documents"
            echo ""
            docker exec -it $CONTAINER_NAME mongosh -u $MONGO_USERNAME -p $MONGO_PASSWORD --authenticationDatabase admin $MONGO_DATABASE
        else
            echo "❌ Interactive shell requires a TTY"
            echo "Available commands:"
            echo "  $0 list          - List all databases"
            echo "  $0 collections   - List collections in vapi database"
            echo "  $0 show <name>   - Show documents in a collection"
            echo "  $0 count <name>  - Count documents in a collection"
            echo "  $0 stats         - Show database statistics"
        fi
        ;;
esac

