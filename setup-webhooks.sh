#!/bin/bash

# Script to set up ngrok tunnel for webhook endpoints
# This exposes the usecases service (port 8082) via ngrok

set -e

USECASES_PORT=${USECASES_PORT:-8082}
NGROK_PORT=${NGROK_PORT:-4040}

echo "🔗 Setting up ngrok tunnel for webhook endpoints..."
echo ""

# Check if usecases service is running
if ! curl -s http://localhost:$USECASES_PORT/health > /dev/null 2>&1; then
    echo "❌ Usecases service is not running on port $USECASES_PORT"
    echo "   Please start the services with: docker-compose up -d"
    exit 1
fi

echo "✅ Usecases service is running on port $USECASES_PORT"
echo ""

# Check if ngrok is already running
if pgrep -f "ngrok http $USECASES_PORT" > /dev/null; then
    echo "⚠️  ngrok is already running for port $USECASES_PORT"
    echo ""
    echo "📋 Current webhook URLs:"
    echo ""
    NGROK_URL=$(curl -s http://localhost:$NGROK_PORT/api/tunnels | grep -o '"public_url":"https://[^"]*"' | head -1 | cut -d'"' -f4)
    if [ -n "$NGROK_URL" ]; then
        echo "  Survey Answer:     $NGROK_URL/v1/api/survey/answer"
        echo "  Call Centre Call:  $NGROK_URL/v1/api/call-centre/call"
        echo "  Assistant Call:    $NGROK_URL/v1/api/assistant/call"
    else
        echo "  Could not retrieve ngrok URL. Check ngrok dashboard: http://localhost:$NGROK_PORT"
    fi
    echo ""
    echo "To stop ngrok, run: pkill -f 'ngrok http $USECASES_PORT'"
    exit 0
fi

# Start ngrok in background
echo "🚀 Starting ngrok tunnel..."
ngrok http $USECASES_PORT > /tmp/ngrok.log 2>&1 &
NGROK_PID=$!

# Wait for ngrok to start
echo "⏳ Waiting for ngrok to start..."
sleep 3

# Check if ngrok started successfully
if ! kill -0 $NGROK_PID 2>/dev/null; then
    echo "❌ Failed to start ngrok. Check /tmp/ngrok.log for details"
    exit 1
fi

# Get ngrok URL from API
echo "📡 Retrieving ngrok URL..."
for i in {1..10}; do
    NGROK_URL=$(curl -s http://localhost:$NGROK_PORT/api/tunnels 2>/dev/null | grep -o '"public_url":"https://[^"]*"' | head -1 | cut -d'"' -f4)
    if [ -n "$NGROK_URL" ]; then
        break
    fi
    sleep 1
done

if [ -z "$NGROK_URL" ]; then
    echo "⚠️  Could not retrieve ngrok URL automatically"
    echo "   Check ngrok dashboard: http://localhost:$NGROK_PORT"
    echo "   Or check /tmp/ngrok.log"
    exit 1
fi

echo ""
echo "✅ ngrok tunnel is running!"
echo ""
echo "📋 Webhook URLs:"
echo ""
echo "  Survey Answer:     $NGROK_URL/v1/api/survey/answer"
echo "  Call Centre Call:  $NGROK_URL/v1/api/call-centre/call"
echo "  Assistant Call:    $NGROK_URL/v1/api/assistant/call"
echo ""
echo "📊 ngrok Dashboard: http://localhost:$NGROK_PORT"
echo ""
echo "💡 To stop ngrok, run: pkill -f 'ngrok http $USECASES_PORT'"
echo ""
echo "⚠️  Note: These URLs will change if you restart ngrok (unless using paid plan)"
echo "   Save these URLs and update your VAPI assistant configurations accordingly"

