import {
  Box,
  Card,
  HStack,
  Image,
  VStack,
  Text,
  Button,
  Flex,
  Link,
} from "@chakra-ui/react";
import { MdOutlineArrowOutward } from "react-icons/md";

export const InfoCard = () => {
  return (
    <Card w={"full"} borderRadius={16}>
      <Box p={3}>
        <VStack w={"full"} spacing={{ base: 2, md: 4 }}>
          <Image src="/homedisplay.jpg"/>
          <Button p="30px 20px"
              ms="40px"
              me="10px"
              bg= 'white'
              color="black"
              border="solid 1px black"
              sx={{ _hover: {bg:"black", color:"white"}}}>Start now !</Button>
          {/* <Flex
            w={"full"}
            justifyContent={"space-between"}
            direction={{ base: "column", md: "row" }}
            alignItems={"center"}
          >
            <HStack alignSelf={{ base: "center", md: "flex-start" }}>
              <Image src="/logo.png" h={16} borderRadius={16} />
              <Text fontSize={24} fontWeight={800}>
                EcoEarn
              </Text>
            </HStack>
            <Flex
              mt={{ base: 4, md: 0 }}
              direction={{ base: "column", md: "row" }}
            >
              <Link isExternal href="https://github.com/vechain/x-app-template">
                <Button
                  rounded={"full"}
                  colorScheme="primary"
                  size={"md"}
                  leftIcon={<MdOutlineArrowOutward />}
                  mt={{ base: 2, md: 0 }}
                  ml={{ base: 0, md: 2 }}
                >
                  Github repository
                </Button>
              </Link>
            </Flex>
          </Flex> */}
        </VStack>
      </Box>
    </Card>
  );
};
