class NotificationListener < BaseListener
  def conversation_bot_handoff(event)
    conversation, account = extract_conversation_and_account(event)
    return if conversation.pending?

    conversation.inbox.members.each do |agent|
      NotificationBuilder.new(
        notification_type: 'conversation_creation',
        user: agent,
        account: account,
        primary_actor: conversation
      ).perform
    end
  end

  def conversation_created(event)
    conversation, account = extract_conversation_and_account(event)
    return if conversation.pending?

    conversation.inbox.members.each do |agent|
      NotificationBuilder.new(
        notification_type: 'conversation_creation',
        user: agent,
        account: account,
        primary_actor: conversation
      ).perform
    end
  end

  def assignee_changed(event)
    conversation, account = extract_conversation_and_account(event)
    assignee = conversation.assignee

    return if assignee.blank?
    return if event.data[:notifiable_assignee_change].blank?
    return if conversation.pending?

    NotificationBuilder.new(
      notification_type: 'conversation_assignment',
      user: assignee,
      account: account,
      primary_actor: conversation
    ).perform
  end

  def message_created(event)
    message, account = extract_message_and_account(event)
    conversation = message.conversation

    return if conversation.pending?
    return if message.private?
    return unless message.incoming?

    # Keep mentioning behavior
    Messages::MentionService.new(message: message).perform

    # IMPORTANT:
    # If you keep Chatwoot's default new-message service,
    # you'll likely generate duplicate notifications.
    # Comment it out if you're notifying everyone manually.
    Messages::NewMessageNotificationService.new(message: message).perform

    conversation.inbox.members.each do |agent|
      next if agent.id == message.sender_id

      NotificationBuilder.new(
        notification_type: 'assigned_conversation_new_message',
        user: agent,
        account: account,
        primary_actor: conversation,
        secondary_actor: message
      ).perform
    end
  end
end
