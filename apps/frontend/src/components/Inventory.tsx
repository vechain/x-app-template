import React, { useState, useEffect } from 'react';
import axios from 'axios';

// Define the type for inventory items
interface InventoryItem {
    id: string;
    name: string;
    expiryDate: string;
    imageSrc?: string;
}

// Define the type for API responses
interface FoodLabel {
    description: string;
}

// Function to detect food using an image recognition API (e.g., Azure, Amazon Rekognition)
const detectFood = async (imageData: string) => {
    const apiEndpoint = '.'; // Replace with your API endpoint 
    const apiKey = '.'; // Replace with your API key 
    
    try {
        const response = await axios.post(apiEndpoint, { image: imageData }, {
            headers: {
                'Authorization': `Bearer ${apiKey}`,
                'Content-Type': 'application/json',
            }
        });
        return response.data.labels || [];
    } catch (error) {
        if (axios.isAxiosError(error)) {
            if (error.response) {
                // Server responded with an error status
                console.error('API Error:', error.response.data);
                throw new Error(`API Error: ${error.response.status} - ${error.response.data.message || 'An error occurred.'}`);
            } else if (error.request) {
                // No response received
                console.error('No Response:', error.request);
                throw new Error('No response received from the API.');
            } else {
                // Request setup error
                console.error('Error Message:', error.message);
                throw new Error(`Request Error: ${error.message}`);
            }
        } else {
            // Non-Axios error
            console.error('Unexpected Error:', error);
            throw new Error('An unexpected error occurred.');
        }
    }
};

// Function to estimate expiry date based on description
const estimateExpiryDate = async (description: string) => {
    const apiKey = '.'; // OpenAI API key
    const endpoint = 'https://api.openai.com/v1/completions'; // Updated endpoint
    
    const prompt = `Given the description of a food item, estimate the expiry date. Description: ${description}`;

    try {
        const response = await axios.post(endpoint, {
            model: 'text-davinci-003',
            prompt: prompt,
            max_tokens: 50,
        }, {
            headers: {
                'Authorization': `Bearer ${apiKey}`,
                'Content-Type': 'application/json',
            }
        });
        return response.data.choices[0].text.trim();
    } catch (error) {
        console.error('Error estimating expiry date:', error);
        throw new Error('Failed to estimate expiry date. Please try again.'); // Throw an error to handle in the component
    }
};

// Function to get food name from description
const getFoodName = async (description: string) => {
    const apiKey = 'your-openai-api-key'; // OpenAI API key
    const endpoint = 'https://api.openai.com/v1/completions'; // Updated endpoint
    
    const prompt = `Given the description of a food item, determine its name. Description: ${description}`;

    try {
        const response = await axios.post(endpoint, {
            model: 'text-davinci-003',
            prompt: prompt,
            max_tokens: 50,
        }, {
            headers: {
                'Authorization': `Bearer ${apiKey}`,
                'Content-Type': 'application/json',
            }
        });
        return response.data.choices[0].text.trim();
    } catch (error) {
        console.error('Error getting food name:', error);
        throw new Error('Failed to get food name. Please try again.'); // Throw an error to handle in the component
    }
};

const Inventory: React.FC = () => {
    const [items, setItems] = useState<InventoryItem[]>([]);
    const [imageSrc, setImageSrc] = useState<string | undefined>(undefined);
    const [isProcessing, setIsProcessing] = useState(false); // To handle loading state
    const [error, setError] = useState<string | undefined>(undefined); // State for error message

    // Load inventory items from local storage when the component mounts
    useEffect(() => {
        if (typeof localStorage !== 'undefined') {
            const storedItems = localStorage.getItem('inventory');
            if (storedItems) {
                setItems(JSON.parse(storedItems));
            }
        }
    }, []);

    // Handle image upload and set the image source
    const handleImageUpload = async (event: React.ChangeEvent<HTMLInputElement>) => {
        const file = event.target.files?.[0];
        if (file) {
            const reader = new FileReader();
            reader.onload = async () => {
                const imageData = reader.result as string;
                setImageSrc(imageData);
                setIsProcessing(true);
                setError(undefined); // Clear any previous errors
                
                try {
                    // Call the image recognition API
                    const labels = await detectFood(imageData);
                    console.log('Detected labels:', labels);

                    // Determine food description from labels
                    const foodDescriptions = labels.map((label: { description: any; }) => label.description).join(', ');
                    
                    if (foodDescriptions) {
                        // Automatically generate item details
                        const name = await getFoodName(foodDescriptions);
                        const expiryDate = await estimateExpiryDate(foodDescriptions);

                        if (name && expiryDate) {
                            const newItem: InventoryItem = {
                                id: Date.now().toString(),
                                name,
                                expiryDate,
                                imageSrc,
                            };
                            const updatedItems = [...items, newItem];
                            setItems(updatedItems);

                            // Store in local storage
                            if (typeof localStorage !== 'undefined') {
                                localStorage.setItem('inventory', JSON.stringify(updatedItems));
                            }
                        }
                    }
                } catch (error) {
                    if (error instanceof Error) {
                        setError(error.message); // Set the error message
                    }
                } finally {
                    setImageSrc(undefined);
                    setIsProcessing(false);
                }
            };
            reader.onerror = () => {
                setError('Failed to read file. Please try again.'); // Set error message for file read failure
                setIsProcessing(false);
            };
            reader.readAsDataURL(file);
        }
    };

    // Function to delete an item
    const handleDelete = (id: string) => {
        const updatedItems = items.filter(item => item.id !== id);
        setItems(updatedItems);

        // Update local storage
        if (typeof localStorage !== 'undefined') {
            localStorage.setItem('inventory', JSON.stringify(updatedItems));
        }
    };

    // Function to check if an item is urgent (within 7 days of expiry)
    const isUrgent = (expiryDate: string) => {
        const currentDate = new Date();
        const expiry = new Date(expiryDate);
        const differenceInTime = expiry.getTime() - currentDate.getTime();
        const differenceInDays = differenceInTime / (1000 * 3600 * 24);
        return differenceInDays <= 7; // Items expiring in 7 days or less are marked as urgent
    };

    // Split items into urgent and normal categories
    const urgentItems = items.filter((item) => isUrgent(item.expiryDate));
    const normalItems = items.filter((item) => !isUrgent(item.expiryDate));

    return (
        <div style={{ maxWidth: '900px', margin: '0 auto', padding: '20px', fontFamily: 'Arial, sans-serif' }}>
            <h1 style={{ textAlign: 'center', marginBottom: '20px', color: '#333' }}>Inventory Manager</h1>

            {/* Form for adding items */}
            <form style={{ display: 'flex', flexDirection: 'column', gap: '15px', marginBottom: '30px', border: '1px solid #ccc', padding: '20px', borderRadius: '8px', backgroundColor: '#f4f4f4', boxShadow: '0 4px 8px rgba(0, 0, 0, 0.1)' }}>
                <label style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    Upload Image:
                    <input
                        type="file"
                        accept="image/*"
                        onChange={handleImageUpload}
                        style={{ padding: '8px', width: '70%', borderRadius: '5px', border: '1px solid #ccc' }}
                    />
                </label>
                {isProcessing && <p>Processing image, please wait...</p>}
                {error && <p style={{ color: 'red', fontWeight: 'bold' }}>{error}</p>}
            </form>

            {/* Display inventory items side by side */}
            <div style={{ display: 'flex', gap: '20px', flexWrap: 'wrap' }}>
                <div style={{ flex: 1, minWidth: '250px' }}>
                    <h2 style={{ textAlign: 'center', color: '#ff4d4d', fontSize: '24px', fontWeight: 'bold', textTransform: 'uppercase', borderBottom: '2px solid #ff4d4d', paddingBottom: '10px' }}>Urgent Inventory</h2>
                    <ul style={{ listStyleType: 'none', padding: 0 }}>
                        {urgentItems.map((item) => (
                            <li key={item.id} style={{ border: '1px solid #ff4d4d', padding: '15px', marginBottom: '15px', borderRadius: '8px', backgroundColor: '#ffe6e6', boxShadow: '0 2px 4px rgba(0, 0, 0, 0.1)' }}>
                                <h3>{item.name}</h3>
                                <p>Expiry Date: {item.expiryDate}</p>
                                {item.imageSrc && <img src={item.imageSrc} alt={item.name} style={{ maxWidth: '100%', height: 'auto', borderRadius: '5px', marginTop: '10px' }} />}
                                <button onClick={() => handleDelete(item.id)} style={{ padding: '5px', backgroundColor: '#dc3545', color: 'white', border: 'none', borderRadius: '5px', cursor: 'pointer', marginTop: '10px' }}>
                                    Delete
                                </button>
                            </li>
                        ))}
                    </ul>
                </div>

                <div style={{ flex: 1, minWidth: '250px' }}>
                    <h2 style={{ textAlign: 'center', color: '#007BFF', fontSize: '24px', fontWeight: 'bold', textTransform: 'uppercase', borderBottom: '2px solid #007BFF', paddingBottom: '10px' }}>Normal Inventory</h2>
                    <ul style={{ listStyleType: 'none', padding: 0 }}>
                        {normalItems.map((item) => (
                            <li key={item.id} style={{ border: '1px solid #007BFF', padding: '15px', marginBottom: '15px', borderRadius: '8px', backgroundColor: '#e6f7ff', boxShadow: '0 2px 4px rgba(0, 0, 0, 0.1)' }}>
                                <h3>{item.name}</h3>
                                <p>Expiry Date: {item.expiryDate}</p>
                                {item.imageSrc && <img src={item.imageSrc} alt={item.name} style={{ maxWidth: '100%', height: 'auto', borderRadius: '5px', marginTop: '10px' }} />}
                                <button onClick={() => handleDelete(item.id)} style={{ padding: '5px', backgroundColor: '#dc3545', color: 'white', border: 'none', borderRadius: '5px', cursor: 'pointer', marginTop: '10px' }}>
                                    Delete
                                </button>
                            </li>
                        ))}
                    </ul>
                </div>
            </div>
        </div>
    );
};

export default Inventory;
