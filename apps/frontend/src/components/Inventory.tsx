import React, { useState, useEffect } from 'react';

// Define the type for inventory items
interface InventoryItem {
    id: string;
    name: string;
    expiryDate: string;
    imageSrc?: string;
}

const Inventory: React.FC = () => {
    const [items, setItems] = useState<InventoryItem[]>([]);
    const [name, setName] = useState('');
    const [expiryDate, setExpiryDate] = useState('');
    const [imageSrc, setImageSrc] = useState<string | undefined>(undefined);

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
    const handleImageUpload = (event: React.ChangeEvent<HTMLInputElement>) => {
        const file = event.target.files?.[0];
        if (file) {
            const reader = new FileReader();
            reader.onload = () => setImageSrc(reader.result as string);
            reader.onerror = () => console.error('Failed to read file.');
            reader.readAsDataURL(file);
        }
    };

    // Handle form submission to add a new item to the inventory
    const handleSubmit = (event: React.FormEvent) => {
        event.preventDefault();
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

            // Reset form fields
            setName('');
            setExpiryDate('');
            setImageSrc(undefined);
        }
    };

    return (
        <div style={{ maxWidth: '600px', margin: '0 auto', padding: '20px', fontFamily: 'Arial, sans-serif' }}>
            <h1>Inventory Manager</h1>
            {/* Form for adding items */}
            <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '10px', marginBottom: '20px' }}>
                <label>
                    Item Name:
                    <input
                        type="text"
                        value={name}
                        onChange={(e) => setName(e.target.value)}
                        required
                        style={{ marginLeft: '10px', padding: '5px' }}
                    />
                </label>
                <label>
                    Expiry Date:
                    <input
                        type="date"
                        value={expiryDate}
                        onChange={(e) => setExpiryDate(e.target.value)}
                        required
                        style={{ marginLeft: '10px', padding: '5px' }}
                    />
                </label>
                <label>
                    Upload Image:
                    <input
                        type="file"
                        accept="image/*"
                        onChange={handleImageUpload}
                        style={{ marginLeft: '10px', padding: '5px' }}
                    />
                </label>
                <button type="submit" style={{ padding: '10px', backgroundColor: '#007BFF', color: 'white', border: 'none', borderRadius: '5px' }}>
                    Add to Inventory
                </button>
            </form>

            {/* Display inventory items */}
            <h2>Current Inventory</h2>
            <ul style={{ listStyleType: 'none', padding: 0 }}>
                {items.map((item) => (
                    <li key={item.id} style={{ border: '1px solid #ccc', padding: '10px', marginBottom: '10px' }}>
                        <h3>{item.name}</h3>
                        <p>Expiry Date: {item.expiryDate}</p>
                        {item.imageSrc && <img src={item.imageSrc} alt={item.name} style={{ maxWidth: '100px', height: 'auto', display: 'block', marginTop: '10px' }} />}
                    </li>
                ))}
            </ul>
        </div>
    );
};

export default Inventory;

