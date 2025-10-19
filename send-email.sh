#!/bin/bash
# Reusable email notification script using msmtp

set -e
set -u

# Configuration
SUBJECT_PREFIX="[dungeonware]"

# Usage information
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] EMAIL SUBJECT

Send email notification using msmtp.

ARGUMENTS:
    EMAIL                   Recipient email address
    SUBJECT                 Email subject

OPTIONS:
    -b, --body TEXT         Email body text
    -f, --file FILE         Read body from file
    -h, --help              Show this help message
EOF
    exit 1
}

# Send email function
send_email() {
    local recipient="$1"
    local subject="$2"
    local body="$3"
    
    if ! command -v msmtp >/dev/null 2>&1; then
        echo "Error: msmtp not found. Please install msmtp." >&2
        return 1
    fi
    
    # Prepare email with prefix
    local full_subject="${SUBJECT_PREFIX} ${subject}"
    
    # Send email
    if echo -e "Subject: $full_subject\n\n$body" | msmtp "$recipient"; then
        echo "Email sent successfully to $recipient"
        return 0
    else
        echo "Error: Failed to send email" >&2
        return 1
    fi
}

# Main script
main() {
    local subject=""
    local body=""
    local body_file=""
    local email=""
    local positional_args=()
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -b|--body)
                body="$2"
                shift 2
                ;;
            -f|--file)
                body_file="$2"
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            -*)
                echo "Error: Unknown option: $1" >&2
                usage
                ;;
            *)
                positional_args+=("$1")
                shift
                ;;
        esac
    done
    
    # Check if we have email and subject
    if [[ ${#positional_args[@]} -lt 2 ]]; then
        echo "Error: Email and subject are required" >&2
        usage
    fi
    
    email="${positional_args[0]}"
    subject="${positional_args[1]}"
    
    # Get body content
    if [[ -n "$body_file" ]]; then
        if [[ -f "$body_file" ]]; then
            body=$(cat "$body_file")
        else
            echo "Error: File not found: $body_file" >&2
            exit 1
        fi
    elif [[ -z "$body" ]]; then
        # Read from stdin if no body provided
        if [[ -t 0 ]]; then
            # stdin is a terminal, no piped input
            body="(No message body provided)"
        else
            # Read from pipe
            body=$(cat)
        fi
    fi
    
    # Send the email
    send_email "$email" "$subject" "$body"
}

# Run main function
main "$@"
