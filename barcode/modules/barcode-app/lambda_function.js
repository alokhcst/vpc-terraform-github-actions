const AWS = require('aws-sdk');
const crypto = require('crypto');

// Initialize AWS services
const cognito = new AWS.CognitoIdentityServiceProvider({
    region: '${region}'
});

// Lambda function handler
exports.handler = async (event) => {
    const headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'POST,OPTIONS'
    };

    // Handle preflight requests
    if (event.httpMethod === 'OPTIONS') {
        return {
            statusCode: 200,
            headers,
            body: ''
        };
    }

    try {
        // Parse the request body
        const body = JSON.parse(event.body);
        const { jwt_token } = body;

        if (!jwt_token) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({
                    error: 'JWT token is required'
                })
            };
        }

        // Verify JWT token with Cognito
        const isValid = await verifyJWTToken(jwt_token);
        if (!isValid.valid) {
            return {
                statusCode: 401,
                headers,
                body: JSON.stringify({
                    error: isValid.error || 'Invalid JWT token'
                })
            };
        }

        // Decode JWT payload
        const tokenParts = jwt_token.split('.');
        const payload = JSON.parse(Buffer.from(tokenParts[1], 'base64').toString());
        
        // Check if token is expired
        const currentTime = Math.floor(Date.now() / 1000);
        if (payload.exp && payload.exp < currentTime) {
            return {
                statusCode: 401,
                headers,
                body: JSON.stringify({
                    error: 'JWT token has expired'
                })
            };
        }

        // Generate barcode data based on JWT claims
        const barcodeData = {
            user_id: payload.sub || 'unknown',
            username: payload['cognito:username'] || payload.email || 'user',
            email: payload.email || '',
            iat: payload.iat,
            exp: payload.exp,
            token_use: payload.token_use || 'access',
            // Create a unique identifier for this session
            session_id: crypto.createHash('sha256').update(jwt_token.substring(0, 50)).digest('hex').substring(0, 12)
        };

        // Generate barcode content (you can customize this format)
        const barcodeContent = `USER:${barcodeData.username}|ID:${barcodeData.user_id}|SESSION:${barcodeData.session_id}|EXP:${barcodeData.exp}`;

        // Generate simple ASCII barcode representation
        const barcode = generateSimpleBarcode(barcodeContent);

        return {
            statusCode: 200,
            headers,
            body: JSON.stringify({
                success: true,
                barcode_data: barcodeData,
                barcode_content: barcodeContent,
                barcode_ascii: barcode,
                barcode_svg: generateBarcodeSVG(barcodeContent),
                generated_at: new Date().toISOString()
            })
        };

    } catch (error) {
        console.error('Error generating barcode:', error);
        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({
                error: 'Internal server error',
                message: error.message
            })
        };
    }
};

// Verify JWT token with Cognito (simplified version)
async function verifyJWTToken(token) {
    try {
        // In a production environment, you would verify the token signature
        // using the Cognito public keys (JWKs)
        const tokenParts = token.split('.');
        if (tokenParts.length !== 3) {
            return { valid: false, error: 'Invalid token format' };
        }

        const payload = JSON.parse(Buffer.from(tokenParts[1], 'base64').toString());
        
        // Basic validation
        if (!payload.iss || !payload.iss.includes('cognito')) {
            return { valid: false, error: 'Invalid token issuer' };
        }

        if (payload.token_use !== 'access' && payload.token_use !== 'id') {
            return { valid: false, error: 'Invalid token use' };
        }

        // Check if token is from the correct user pool
        const expectedIssuer = `https://cognito-idp.${process.env.AWS_REGION}.amazonaws.com/${process.env.USER_POOL_ID}`;
        if (payload.iss !== expectedIssuer) {
            return { valid: false, error: 'Token from wrong user pool' };
        }

        return { valid: true };
    } catch (error) {
        console.error('Token verification error:', error);
        return { valid: false, error: 'Token verification failed' };
    }
}

// Simple barcode generator (Code 39 style representation)
function generateSimpleBarcode(data) {
    // Simple mapping for demonstration - in production use a proper barcode library
    const code39 = {
        '0': '000110100', '1': '100100001', '2': '001100001', '3': '101100000',
        '4': '000110001', '5': '100110000', '6': '001110000', '7': '000100101',
        '8': '100100100', '9': '001100100', 'A': '100001001', 'B': '001001001',
        'C': '101001000', 'D': '000011001', 'E': '100011000', 'F': '001011000',
        'G': '000001101', 'H': '100001100', 'I': '001001100', 'J': '000011100',
        'K': '100000011', 'L': '001000011', 'M': '101000010', 'N': '000010011',
        'O': '100010010', 'P': '001010010', 'Q': '000000111', 'R': '100000110',
        'S': '001000110', 'T': '000010110', 'U': '110000001', 'V': '011000001',
        'W': '111000000', 'X': '010010001', 'Y': '110010000', 'Z': '011010000',
        ' ': '011000100', '*': '010010100', ':': '010010100', '|': '010010100'
    };

    let barcode = '';
    const cleanData = data.toUpperCase().replace(/[^A-Z0-9 :\|*]/g, '');
    
    // Add start character
    barcode += code39['*'] + '0';
    
    for (let char of cleanData) {
        if (code39[char]) {
            barcode += code39[char] + '0';
        }
    }
    
    // Add stop character
    barcode += code39['*'];
    
    // Convert to ASCII representation
    let asciiBarcode = '';
    for (let bit of barcode) {
        asciiBarcode += bit === '1' ? '█' : '▁';
    }
    
    return asciiBarcode;
}

// Generate SVG barcode
function generateBarcodeSVG(data) {
    const cleanData = data.toUpperCase().replace(/[^A-Z0-9 :\|*]/g, '');
    const width = Math.max(400, cleanData.length * 12);
    const height = 100;
    
    // Simple barcode pattern generation
    let pattern = '';
    for (let i = 0; i < cleanData.length; i++) {
        // Alternate thick and thin bars based on character code
        const charCode = cleanData.charCodeAt(i);
        pattern += charCode % 2 === 0 ? '11001100' : '10011001';
    }
    
    let svg = `<svg width="${width}" height="${height}" xmlns="http://www.w3.org/2000/svg">`;
    svg += `<rect width="${width}" height="${height}" fill="white"/>`;
    
    let x = 20;
    const barWidth = (width - 40) / pattern.length;
    
    for (let i = 0; i < pattern.length; i++) {
        if (pattern[i] === '1') {
            svg += `<rect x="${x}" y="15" width="${barWidth}" height="60" fill="black"/>`;
        }
        x += barWidth;
    }
    
    // Add text below barcode
    svg += `<text x="${width/2}" y="90" text-anchor="middle" font-family="monospace" font-size="10" fill="black">${data.substring(0, 50)}</text>`;
    svg += '</svg>';
    
    return svg;
}