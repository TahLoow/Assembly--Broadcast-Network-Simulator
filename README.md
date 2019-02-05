# AssemblyProject4

This group project was completed in Microsoft Assembler (MASM). The finished product does the following:
- User chooses input network/graph topology type. (Should node A be connected to B, and B to C the command entered is AB BC):
   - Topology read from keyboard input
   - Topology read from a file
   - A default six-node network, equivalent to AB BC CD DF FE EA BF CE
- Determines whether the input/chosen network is connected.
- Prompts the user for a source node. Must be a declared node.
- Prompts the user for a destination node. Must be a declared node.
- Prompts the user to run with or without echo
   - Echo permits a node to send a packet from where the packet was received
- Places original packet into source node queue, with time-to-live, destination, and other flags in the packet.
- Primary operation begins:
   1 Loops through all nodes
   2 Duplicates packets into neighboring node queues, decrementing their TTL
   3 Records all transmitted/received packets
   4 Increments program time each time all nodes have been cycled through
- Displays how many packets reached the destination within their TTL, how many were generated in total, and how long until they all died.


