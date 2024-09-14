import { Card, CardBody, Flex, Button, Image, Text } from "@chakra-ui/react";
import { Link } from "react-router-dom";
import "./home.css";

export default function Home() {
  return (
    <div style={{ backgroundColor: "#c5dcc2" }}>
      <div style={{ position: "absolute", top: "10px", right: "10px" }}>
        <Button
          bg="#2a3d29"
          color="#c5dcc2"
          _hover={{ bg: "#c5dcc2", color: "#2a3d29" }}
          width="100px"
          margin="3"
        >
          Profile
        </Button>
      </div>
      <div className="parallax"></div>
      <Image src="/hill.png" />

      <div className="scroll-container" style={{ backgroundColor: "#4e6b4c" }}>
        <Flex justifyContent="center" alignItems="center" height="100%" gap={8}>
          <div>
            <Text color="#efefef" fontSize="5xl">
              REDUCE
            </Text>
            <Card
              bg="#efefef"
              minHeight="350"
              paddingTop="200"
              borderRadius="25"
            >
              <Image
                src="/reduce.png"
                position="absolute"
                top="-80px"
                left="50%"
                transform="translateX(-50%)"
                width="300px"
              />

              <CardBody>
                <Text fontSize="md">
                  View a summary of all your customers over the last month.
                </Text>

                <Flex justify="center" mt="4">
                  <Link to="/reduceForm" style={{ textDecoration: "none" }}>
                    <Button
                      bg="#2a3d29"
                      color="#c5dcc2"
                      _hover={{ bg: "#c5dcc2", color: "#2a3d29" }}
                      width="200px"
                    >
                      Get your vet!
                    </Button>
                  </Link>
                </Flex>
              </CardBody>
            </Card>
          </div>

          <div>
            <Text color="#efefef" fontSize="5xl" textAlign="right">
              OFFSET
            </Text>
            <Card
              bg="#efefef"
              minHeight="350"
              paddingTop="200"
              borderRadius="25"
            >
              <Image
                src="/offset.png"
                position="absolute"
                top="-90px"
                left="50%"
                transform="translateX(-70%)"
                width="300px"
              />

              <CardBody>
                <Text fontSize="md">
                  View a summary of all your customers over the last month.
                </Text>

                <Flex justify="center" mt="4">
                  <Link to="/offsetForm" style={{ textDecoration: "none" }}>
                    <Button
                      bg="#2a3d29"
                      color="#c5dcc2"
                      _hover={{ bg: "#c5dcc2", color: "#2a3d29" }}
                      width="200px"
                    >
                      Get your vet!
                    </Button>
                  </Link>
                </Flex>
              </CardBody>
            </Card>
          </div>
        </Flex>
      </div>
    </div>
  );
}
