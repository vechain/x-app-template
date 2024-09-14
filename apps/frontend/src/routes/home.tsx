import React from "react";
import { Container, Flex } from "@chakra-ui/react";
import {
    Dropzone,
    InfoCard,
    Instructions,
} from "../components";

export default function Home() {
    return (
        <Flex flex={1}>
            <Container
                mt={{ base: 4, md: 10 }}
                maxW={"container.xl"}
                mb={{ base: 4, md: 10 }}
                display={"flex"}
                flex={1}
                alignItems={"center"}
                justifyContent={"flex-start"}
                flexDirection={"column"}
            >
                <InfoCard />
                <Instructions />
                <Dropzone />
            </Container>
        </Flex>
    );
}