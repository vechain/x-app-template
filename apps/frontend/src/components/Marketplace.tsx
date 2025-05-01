import {
  Box,
  Button,
  Card,
  CardBody,
  Grid,
  HStack,
  Heading,
  Image,
  Input,
  Text,
  Textarea,
  VStack,
  useToast,
} from '@chakra-ui/react';
import { MarketplaceItem, supabase } from '../networking/supabase';
import { useEffect, useState } from 'react';

import { useWallet } from '@vechain/dapp-kit-react';

export const Marketplace = () => {
  const [items, setItems] = useState<MarketplaceItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [newItem, setNewItem] = useState({
    title: '',
    description: '',
    price: 0,
    image_url: '',
  });
  const { account } = useWallet();
  const toast = useToast();

  useEffect(() => {
    fetchItems();
  }, []);

  const fetchItems = async () => {
    try {
      const { data, error } = await supabase
        .from('marketplace_items')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setItems(data || []);
    } catch (error) {
      console.error('Error fetching items:', error);
      toast({
        title: 'Error',
        description: 'Failed to fetch marketplace items',
        status: 'error',
      });
    } finally {
      setLoading(false);
    }
  };

  const handleCreateItem = async () => {
    if (!account) {
      toast({
        title: 'Error',
        description: 'Please connect your wallet first',
        status: 'error',
      });
      return;
    }

    try {
      const { data, error } = await supabase
        .from('marketplace_items')
        .insert([
          {
            ...newItem,
            seller_address: account,
            status: 'available',
          },
        ])
        .select();

      if (error) throw error;

      setItems([...(data || []), ...items]);
      setNewItem({
        title: '',
        description: '',
        price: 0,
        image_url: '',
      });

      toast({
        title: 'Success',
        description: 'Item listed successfully',
        status: 'success',
      });
    } catch (error) {
      console.error('Error creating item:', error);
      toast({
        title: 'Error',
        description: 'Failed to create item',
        status: 'error',
      });
    }
  };

  return (
    <Box p={4}>
      <VStack spacing={8} align="stretch">
        <Heading>Marketplace</Heading>

        {/* Create New Item Form */}
        <Card>
          <CardBody>
            <VStack spacing={4}>
              <Input
                placeholder="Title"
                value={newItem.title}
                onChange={(e) => setNewItem({ ...newItem, title: e.target.value })}
              />
              <Textarea
                placeholder="Description"
                value={newItem.description}
                onChange={(e) => setNewItem({ ...newItem, description: e.target.value })}
              />
              <Input
                type="number"
                placeholder="Price"
                value={newItem.price}
                onChange={(e) => setNewItem({ ...newItem, price: Number(e.target.value) })}
              />
              <Input
                placeholder="Image URL"
                value={newItem.image_url}
                onChange={(e) => setNewItem({ ...newItem, image_url: e.target.value })}
              />
              <Button colorScheme="blue" onClick={handleCreateItem}>
                List Item
              </Button>
            </VStack>
          </CardBody>
        </Card>

        {/* Items Grid */}
        <Grid templateColumns="repeat(auto-fill, minmax(300px, 1fr))" gap={6}>
          {items.map((item) => (
            <Card key={item.id}>
              <CardBody>
                <Image
                  src={item.image_url}
                  alt={item.title}
                  borderRadius="lg"
                  height="200px"
                  objectFit="cover"
                />
                <VStack align="stretch" mt={4}>
                  <Heading size="md">{item.title}</Heading>
                  <Text>{item.description}</Text>
                  <HStack justify="space-between">
                    <Text fontWeight="bold">{item.price} VET</Text>
                    <Text color={item.status === 'available' ? 'green.500' : 'red.500'}>
                      {item.status}
                    </Text>
                  </HStack>
                </VStack>
              </CardBody>
            </Card>
          ))}
        </Grid>
      </VStack>
    </Box>
  );
}; 