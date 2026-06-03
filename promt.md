Slack/Discord clone

# Global idea

I want to build an internal tool called "Slekke". It will be a clone of Slack and Discord
It will be used to professionaly communicate between team members and or people you add via their id. This will be happening in private or in groups with channels.
Channels can be created, edited, moved and deleted.
Voice channels are a future idea.

# Techstack

Use Flutter for the application.
By base we need to compile to Windows applications. In the future we want to deploy to the web, android, ios and apple devices.
Use tailwind for styling if that is possible

Idk if this is possible with free Firebase
Think of a great way to store messages, This needs to be performant, but not all data in a channel needs to laod at once. It generatively loads when scrolling up.
The messages should also support emoji reactions, replies and images. Maybe let them support markdown?

Authentication will be done with a Google account.

# Flows

At the base a user can create an originisation or join one via an invite token.
When creating an originization, guilds or in this case "A shell" can be created. This will house all categories. In categories, there will be channels. Channels can also have subchannels and so on.

At the topleft, it is possible to change originisations if needed. On the left, you can be invited to other shells if that is needed. But then you are a invitee of a shell and can only see selected channels, This will be specified on invitation.
